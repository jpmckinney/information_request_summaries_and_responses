require 'bundler/setup'

require_relative 'utils'

class NL < Processor
  DIVISION_ID = 'ocd-division/country:ca/province:nl'

  def scrape_responses
    # From bottom of page.
    notes = {
      '1' => 'Information redacted due to personal information.',
      '2' => 'Information redacted due to third party information.',
      '3' => 'Information redacted due to reference to cabinet record.',
      '4' => 'Information redacted due to legal concerns.',
    }

    url = 'http://atipp-search.gov.nl.ca/public/atipp/Search/?show_all=1'
    # Null characters can cause Nokogiri to stop parsing.
    body = client.get(url).env[:raw_body].gsub("\0", '')
    Nokogiri::HTML(body).xpath('//tbody/tr').each do |tr|
      tds = tr.xpath('./td')

      a = tds[0].at_xpath('./a')
      sup = a.xpath('./sup')
      text = sup.text
      sup.remove

      comments = nil
      unless text.empty?
        matches = text.scan(/(?<=\[)\d(?=\])/)
        comments = matches.map{|s| notes[s]}
        assert("no comments found in #{text}"){!comments.empty?}
      end

      dispatch(InformationResponse.new({
        division_id: DIVISION_ID,
        id: a[:href].match(/\d+/)[0],
        identifier: a.text,
        abstract: tds[1].text,
        date: DateTime.strptime(tds[2].text, '%Y-%m-%d').strftime('%Y-%m-%d'),
        organization: tds[3].text,
        download_url: "http://atipp-search.gov.nl.ca#{a[:href]}",
        comments: comments,
      }))
    end
  end

  def download
    store = DownloadStore.new(File.expand_path(File.join('downloads', 'ca_nl'), Dir.pwd))
    connection.raw_connection['information_responses'].find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
      http_response = client.get(response.fetch('download_url'))
      media_type = http_response.headers.fetch('content-type')
      extension = case media_type
      when 'application/pdf'
        '.pdf'
      when 'application/vnd.ms-excel'
        '.xls'
      when 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        '.xlsx'
      else
        error("unrecognized media type: #{media_type}")
        nil
      end
      if extension
        path = "#{response.fetch('id')}#{extension}"
        store.write(path, http_response.body)
      end
    end
  end
end

NL.add_scraping_task(:responses)

runner = Pupa::Runner.new(NL)
runner.add_action(name: 'download', description: 'Download responses')
runner.run(ARGV)
