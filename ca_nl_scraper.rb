require 'bundler/setup'

require_relative 'lib/utils'

class NL < Processor
  DIVISION_ID = 'ocd-division/country:ca/province:nl'

  COLUMN_WIDTH = 100

  ORGANIZATIONS_MAP = {
    # Scraped data => Open data
    'The Office of the Premier' => "Premier's Office",
    'Intergovernmental and Aboriginal Affairs' => 'Intergovernmental and Aboriginal Affairs Secretariat',
    # Old name => New name
    'Municipal Affairs' => 'Municipal and Intergovernmental Affairs',
    'Justice' => 'Justice and Public Safety',
  }

  def normalize_abstract(text)
    # The scraped data is generally lower quality than the open data:
    #
    # * uses hyphen instead of n-dash
    # * omits unicode bullets
    # * omits trailing parenthesis
    #
    # The open data has some quality issues:
    #
    # * adds trailing numbers
    # * uses incorrect curly quotes
    # * omits alphanumeric bullets
    # * omits period in "etc."
    # * omits trailing period
    # * omits semi-colons
    #
    # Neither uses curly quotes consistently.
    text.gsub(/\p{Space}/, ' ').squeeze(' ').strip.
      # Curly quotes.
      gsub('’', "'").gsub(/[“”]/, '"').

      # Dashes.
      gsub('–', '-').
      # Bullets.
      gsub(/• ([A-Z])/){$1.downcase}.
      # Trailing parenthesis (and period).
      gsub(/[).]+\z/, '').

      # Numbers.
      gsub(/(?<!\d)\.\d{2,}\z/, '').
      # Quotes.
      gsub(' ”', ' “').
      # Bullets.
      gsub(/\b[1-3a-c]\. | -(?= [A-Z])/, '').
      # Period in "etc.".
      gsub(/(?<=\betc\b)(?!\.)/, '.')
  end

  def normalize_organization(text)
    ORGANIZATIONS_MAP.fetch(text, text)
  end

  def format_response(response)
    [
      normalize_abstract(response['abstract']).inspect.scan(/.{1,#{COLUMN_WIDTH}}/),
      [normalize_organization(response['organization'])],
    ]
  end

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

      # The scraped data is generally lower quality than the open data:
      #
      # * adds trailing question marks
      # * "?" or simple quotation mark instead of curly quotation mark
      # * double-hyphen instead of m-dash
      # * "?" instead of hyphen
      # * no space after a semi-colon
      # * inconsistent ampersands

      abstract = tds[1].text.squeeze(' ').strip.
        # Trailing question marks.
        gsub(/ *\?{2,}\z/, '').
        # Curly quotes.
        gsub(/(?<=\bO)\?\b|\b\?(?=s\b| [^A-Z])/, "'").
        gsub(/(?<=[ (])\?\b/, '"').
        gsub(/(?<![? ])\?(?=[),. ][^A-Z])/, '"').
        # Dashes.
        gsub('--', '—').
        # Hyphens.
        gsub(' ? ', ' - ').
        # Spacing.
        gsub(/;(?! )/, '; ').
        # Ampersands.
        gsub(/ B(?: and R)? /, ' B&R ').gsub(' F & A ', ' F&A ')

      dispatch(InformationResponse.new({
        division_id: DIVISION_ID,
        id: a[:href].match(/\d+/)[0],
        identifier: a.text,
        abstract: abstract,
        date: DateTime.strptime(tds[2].text, '%Y-%m-%d').strftime('%Y-%m-%d'),
        organization: tds[3].text,
        download_url: "http://atipp-search.gov.nl.ca#{a[:href]}",
        comments: comments,
      }))
    end
  end

  def download
    store = DownloadStore.new(File.expand_path(File.join('downloads', 'ca_nl'), Dir.pwd))
    collection.find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
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

  def reconcile
    # The open data has the date of decision. The scraped data has the date of
    # publication. We retain the date of publication during reconciliation.

    keys = [
      'id',
      'division_id',
      'identifier',
      'date',
      'abstract',
      'decision',
      'organization',
      'number_of_pages',
    ]

    format_string = "%-#{COLUMN_WIDTH}s  %s"

    summaries = File.expand_path(File.join('summaries'), Dir.pwd)

    csv = {}
    JSON.load(File.read(File.join(summaries, 'ca_nl.json'))).each do |response|
      csv[response['identifier']] ||= []
      csv[response['identifier']] << response
    end

    records = []
    unreconciled_from_scraped_data = []
    collection.find(division_id: DIVISION_ID).each do |expected|
      begin
        expected_identifier = expected['identifier']
        actuals = csv.fetch(expected_identifier)
        response = actuals.find do |actual|
          normalize_abstract(actual.fetch('abstract')) == normalize_abstract(expected.fetch('abstract')) &&
          normalize_organization(actual.fetch('organization')) == normalize_organization(expected.fetch('organization'))
        end

        if response
          records << expected.merge(actuals.delete(response).slice('decision', 'number_of_pages')).slice(*keys)

          if actuals.empty?
            csv.delete(expected_identifier)
          end
        else
          message = []

          # Unreconciled records will be unchanged.
          formatted = format_response(expected)
          actuals.each do |actual|
            format_response(actual).each_with_index do |actual_value,index|
              expected_value = formatted[index]
              unless actual_value == expected_value
                [actual_value.size, expected_value.size].max.times do |n|
                  message << format_string % [expected_value[n], actual_value[n]]
                end
              end
            end
          end

          error("#{expected['id']}\n#{message.join("\n")}")
        end
      rescue KeyError => e
        warn(e)
        # The scraped data has some records not in the open data. In some cases,
        # this is because the scraped data merges requests, e.g. "EC/6/2015-EC/7/2015".
        unreconciled_from_scraped_data << expected.slice(*keys)
      end
    end

    # The open data has some records not in the scraped data.
    unreconciled_from_open_data = csv.values
    info("Adding #{unreconciled_from_open_data.size} unreconciled records from open data")
    records += csv.values.flatten
    info("Adding #{unreconciled_from_scraped_data.size} unreconciled records from scraped data")
    records += unreconciled_from_scraped_data.flatten

    records.sort_by!{|record| record['identifier']}

    # Write the records.
    File.open(File.join(summaries, 'ca_nl.json'), 'w') do |f|
      f << JSON.pretty_generate(records)
    end
    CSV.open(File.join(summaries, 'ca_nl.csv'), 'w') do |csv|
      csv << keys
      records.each do |record|
        csv << keys.map{|key| record[key]}
      end
    end
  end
end

NL.add_scraping_task(:responses)

runner = Pupa::Runner.new(NL)
runner.add_action(name: 'download', description: 'Download responses')
runner.add_action(name: 'reconcile', description: 'Merge CSV data')
runner.run(ARGV)
