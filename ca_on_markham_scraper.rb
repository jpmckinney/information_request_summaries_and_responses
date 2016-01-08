require 'bundler/setup'

require_relative 'lib/utils'

class Markham < Processor
  @jurisdiction_code = 'ca_on_markham'

  def scrape_responses
    url = 'http://www.markham.ca/wps/portal/Markham/MunicipalGovernment/AboutMunicipalGovernment/RecordAccessPrivacy/!ut/p/a0/04_Sj9CPykssy0xPLMnMz0vMAfGjzOJN_N2dnX3CLAKNgkwMDDw9XcJM_VwCDS0CTPQLsh0VAZHUQpY!/'
    table = get(url).xpath('//table[@cellpadding=5][not(@summary)]')

    trs = table.xpath('./tr')
    match = trs[0].text.match(/Activity Report for the period (\S+) – (\S+) (\d+)/)
    year = Integer(match[3])
    period = [1, 2].map{|group| "#{Date.new(year, Date.strptime(match[group], '%B').month, 1).strftime('%Y-%m-%d')}"}.join('/')

    trs.drop(2).each do |tr|
      tds = tr.xpath('./td')
      identifier = tds[0].text

      dispatch(InformationResponse.new({
        id: identifier,
        division_id: 'ocd-division/country:ca/csd:3519036',
        identifier: identifier,
        position: Integer(identifier.match(/\A\d{2}-0*(\d+)\z/)[1]),
        abstract: tds[1].text.strip,
        date: period,
      }))
    end
  end
end

Markham.add_scraping_task(:responses)

runner = Pupa::Runner.new(Markham)
runner.run(ARGV)
