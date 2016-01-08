require 'bundler/setup'

require_relative 'lib/utils'

class Halifax < Processor
  @jurisdiction_code = 'ca_ns_halifax'

  def scrape_responses
    url = 'http://www.halifax.ca/AccessPrivacy/completed-requests/index.php'
    get(url).xpath('//table[@width=611]').each do |table|
      tds = table.xpath('./tr[2]/td')

      text = tds[3].text
      if text['Excel file']
        properties = {}
      else
        properties = {number_of_pages: Integer(text)}
      end

      identifier = tds[0].text
      dispatch(InformationResponse.new({
        id: identifier,
        division_id: 'ocd-division/country:ca/csd:1209034',
        identifier: identifier,
        position: Integer(identifier.match(/\AAR-\d{2}-0*(\d+)\z/)[1]),
        abstract: table.xpath('./tr[3]').text.sub('Request Summary:', '').gsub(/\p{Space}+/, ' ').strip,
        date: DateTime.strptime("#{tds[1].text} #{tds[2].text}", '%Y %B').strftime('%Y-%m'),
        decision: tds[4].text.downcase,
      }.merge(properties)))
    end
  end
end

Halifax.add_scraping_task(:responses)

runner = Pupa::Runner.new(Halifax)
runner.run(ARGV)
