require 'bundler/setup'

require_relative 'lib/utils'

class Markham < Processor
  DIVISION_ID = 'ocd-division/country:ca/csd:3519036'

  @jurisdiction_code = 'ca_on_markham'

  def scrape_responses
    Rails::Html::WhiteListSanitizer.allowed_attributes = %w(href)
    sanitizer = Rails::Html::WhiteListSanitizer.new

    url = 'http://www.markham.ca/wps/portal/Markham/MunicipalGovernment/AboutMunicipalGovernment/RecordAccessPrivacy/!ut/p/a0/04_Sj9CPykssy0xPLMnMz0vMAfGjzOJN_N2dnX3CLAKNgkwMDDw9XcJM_VwCDS0CTPQLsh0VAZHUQpY!/'
    table = get(url).xpath('//table[@cellpadding=5][not(@summary)]')

    trs = table.xpath('.//tr')
    match = trs[0].text.match(/Activity Report for the period (\S+) – (\S+) (\d+)/)
    year = Integer(match[3])
    period = [1, 2].map{|group| "#{Date.new(year, Date.strptime(match[group], '%B').month, 1).strftime('%Y-%m-%d')}"}.join('/')

    trs.drop(2).each do |tr|
      tds = tr.xpath('./td')
      identifier = tds[0].text.strip

      documents = []
      { 'p' => 'order',
        'ul' => 'disclosure',
      }.each do |name,type|
        tds[1].xpath("./#{name}//a").each do |a|
          documents << {
            type: type,
            title: a.text,
            download_url: "http://www.markham.ca#{a[:href]}",
          }
        end
      end

      dispatch(InformationResponse.new({
        id: identifier,
        division_id: 'ocd-division/country:ca/csd:3519036',
        identifier: identifier,
        position: Integer(identifier.match(/\A\d{2}-0*(\d+)\z/)[1]),
        abstract: sanitizer.sanitize(tds[1].inner_html).to_s.gsub(/>\s+</, '><').strip,
        date: period,
        documents: documents,
      }))
    end
  end

  def download
    collection.find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
      response['byte_size'] = 0
      response['number_of_pages'] = 0

      date = Date.parse(response['date'].split('/', 2)[0])
      year = date.strftime('%Y')

      response['documents'].each do |document|
        path = File.join(year, response['identifier'], File.basename(URI.parse(document['download_url']).path))

        unless download_store.exist?(path)
          download_store.write(path, get(URI.escape(document['download_url'])))
        end

        calculate_document_size(document, path)
        response['byte_size'] += document['byte_size']
        response['number_of_pages'] += document['number_of_pages']
      end

      collection.update_one({_id: response['_id']}, response)
    end
  end
end

Markham.add_scraping_task(:responses)

runner = Pupa::Runner.new(Markham)
runner.add_action(name: 'download', description: 'Download responses')
runner.run(ARGV)
