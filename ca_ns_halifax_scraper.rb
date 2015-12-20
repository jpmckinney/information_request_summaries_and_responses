require 'bundler/setup'

require_relative 'lib/utils'

class Halifax < Processor
  def scrape_responses
    url = 'http://www.halifax.ca/AccessPrivacy/completed-requests/index.php'
    get(url).xpath('//table[@width=611]').each do |table|
      tds = table.xpath('./tr[2]/td')

      number_of_pages = tds[3].text
      unless number_of_pages['Excel file']
        number_of_pages = Integer(number_of_pages)
      end

      dispatch(InformationResponse.new({
        division_id: 'ocd-division/country:ca/csd:1209034',
        id: tds[0].text,
        identifier: tds[0].text,
        date: DateTime.strptime("#{tds[1].text} #{tds[2].text}", '%Y %B').strftime('%Y-%m'),
        abstract: table.xpath('./tr[3]').text.sub('Request Summary:', '').strip,
        decision: tds[4].text.downcase,
        number_of_pages: number_of_pages,
      }))
    end
  end
end

Halifax.add_scraping_task(:responses)

runner = Pupa::Runner.new(Halifax)
runner.run(ARGV)
