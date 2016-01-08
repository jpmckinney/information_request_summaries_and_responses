require 'bundler/setup'

require_relative 'lib/utils'

class Ottawa < Processor
  @jurisdiction_code = 'ca_on_ottawa'

  def scrape_responses
    url = 'http://ottawa.ca/en/city-hall/accountability-and-transparency/disclosure-mfippa-requests'
    get(url).xpath('//form[@id="views-form-summary-panel-pane-1"]//@href').each do |href|
      document = get("http://ottawa.ca#{href.value}")
      period = document.xpath('//table/caption').text.scan(/[\d-]{10}/).map{|s| Date.strptime(s, '%d-%m-%Y').strftime('%Y-%m-%d')}.join('/')

      document.xpath('//table//tr[position() > 1]').each do |tr|
        tds = tr.xpath('./td')
        identifier = tds[0].text.gsub(/\p{Space}/, '')

        dispatch(InformationResponse.new({
          id: identifier,
          division_id: 'ocd-division/country:ca/csd:3506008',
          identifier: identifier,
          position: Integer(identifier.match(/\AA-\d{4}-0*(\d+)\z/)[1]),
          abstract: tds[1].text,
          date: period,
        }))
      end
    end
  end
end

Ottawa.add_scraping_task(:responses)

runner = Pupa::Runner.new(Ottawa)
runner.run(ARGV)
