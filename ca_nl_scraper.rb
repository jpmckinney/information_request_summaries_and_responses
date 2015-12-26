require 'bundler/setup'

require_relative 'lib/utils'

class NL < Processor
  DIVISION_ID = 'ocd-division/country:ca/province:nl'

  COLUMN_WIDTH = 100

  # The website has duplicates.
  WEB_DUPLICATES = [
    # Duplicates 380 including PDF (should be about Line 3.1.04.10 as in CSV).
    '648',
  ]
  # The website has incorrect abstracts which should be ignored.
  WEB_BAD_ABSTRACTS = [
    'BTCRD/10/2015', # BTCRD/8/2015
    'TW/21/2015', # EDU/11/2015
  ]

  ORGANIZATIONS_MAP = {
    # Web => CSV
    'The Office of the Premier' => "Premier's Office",
    'Intergovernmental and Aboriginal Affairs' => 'Intergovernmental and Aboriginal Affairs Secretariat',
    # Old name => New name
    'Municipal Affairs' => 'Municipal and Intergovernmental Affairs',
    'Justice' => 'Justice and Public Safety',
  }

  # Map the unpreferred abstract to the preferred abstract.
  WEB_ABSTRACTS_MAP = {
    # Quotation mark (can Levenshtein).
    "A copy of the entire consultants report produced in 2014 on the commercial viability of seal meat, as paid for by the department. The executive summary was provided in early October 2014, but a copy of the full report is requested" =>
    "A copy of the entire consultant's report produced in 2014 on the commercial viability of seal meat, as paid for by the department. The executive summary was provided in early October 2014, but a copy of the full report is requested",
    # Question mark (can Levenshtein).
    "Any documents relating to the following amendments made under sections 8 and 9 of An Act to Amend the Workers? Compensation Act, S.N. 1992, c.29: (a) The addition of section 44.1 of the Workplace Health, Safety and Compensation Commission Act, RSNL 1990, W-11 (the \"WHSC Act\"); and (b) The substitution of section 45 of the WHSC Act. Any documents relating to the following amendment made under section 7 of An Act to Amend the Workers? Compensation Act, S.N. 1994, c/ 12: (a) The addition of section 44.1(2) of the WHSC Act" =>
    "Any documents relating to the following amendments made under sections 8 and 9 of An Act to Amend the Workers' Compensation Act, S.N. 1992, c.29: (a) The addition of section 44.1 of the Workplace Health, Safety and Compensation Commission Act, RSNL 1990, W-11 (the \"WHSC Act\"); and (b) The substitution of section 45 of the WHSC Act. Any documents relating to the following amendment made under section 7 of An Act to Amend the Workers' Compensation Act, S.N. 1994, c/ 12: (a) The addition of section 44.1(2) of the WHSC Act",
    "Number of cheques that the Department of Finance issues per month. Brief description of process required from the time a request for a cheque comes from a lawyer in the Civil Division of the Department of Justice until the cheque is printed and forwarded to that lawyer. Whether or not there is any target timeline for the process outlined in #2 above. 4. If the answer to #3 is yes, what is the target timeline' 5. If the answer to #3 is yes, what are the repercussion for missing the target timeline?" =>
    "Number of cheques that the Department of Finance issues per month. Brief description of process required from the time a request for a cheque comes from a lawyer in the Civil Division of the Department of Justice until the cheque is printed and forwarded to that lawyer. Whether or not there is any target timeline for the process outlined in #2 above. 4. If the answer to #3 is yes, what is the target timeline? 5. If the answer to #3 is yes, what are the repercussion for missing the target timeline?",
    # Repetition.
    "Request the following from April 2012 to present date: The number of ATIPP requests received by the Department of Finance. The number of ATIPP requests received by the Department of Finance. Copies of all Form 1s for each individual request" =>
    "Request the following from April 2012 to present date: The number of ATIPP requests received by the Department of Finance Copies of all Form 1s for each individual request",
    # Update.
    "The names, salaries, and positions of all government appointees to boards and agencies since September 9, 2013. Update 2/10/2015 Remuneration levels for 2 entries have been corrected" =>
    "The names, salaries, and positions of all government appointees to boards and agencies since September 9, 2013",
  }
  CSV_ABSTRACTS_MAP = {
    # Semi-colon (can Levenshtein).
    "Please provide a breakdown by trade and by block The percentage of students from each block exam held between September 2011 and December 2012 (including December 2012) who passed The percentage of those writing each exam between September 2011 and December 2012 (including December 2012) who were writing the exam for the second time The percentage of those writing each exam between September 2011 and December 2012 (including December 2012) who were writing the exam for the third time" =>
    "Please provide a breakdown by trade and by block The percentage of students from each block exam held between September 2011 and December 2012 (including December 2012) who passed; The percentage of those writing each exam between September 2011 and December 2012 (including December 2012) who were writing the exam for the second time; The percentage of those writing each exam between September 2011 and December 2012 (including December 2012) who were writing the exam for the third time",
    # Combined.
    "A copy of any and all emails, memos, correspondence, letters related to Premier designate Frank Coleman and his transition team (including Bill Matthews and Carmel Turpin) for security IDs, office moves, changes to insurance policies to allow any of the above noted people to drive government vehicles as well as details of any costs related to the change in insurance policies" =>
    "Records related to Premier designate Frank Coleman and his transition team (including Bill Matthews and Carmel Turpin) including a full list of the people on the transition team, their positions and remuneration levels, copies of all staffing action requests (including, but not limited to, permanent, temporary, any other hire contracts and position changes), OCIO requests (including requests for new email, network and blackberry accounts), security IDs, and requests to have insurance policies changes to allow any of the above employees to drive government vehicles (and any associated costs to make these insurance policy changes",
    "A copy of any and all emails, memos, correspondence, letters related to Premier designate Frank Coleman and his transition team (including Bill Matthews and Carmel Turpin) This should also include a full list of the people on the transition team, their positions and remuneration levels, copies of all staffing action requests (including, but not limited to, permanent, temporary, any other hire contracts and position changes), OCIO requests (including requests for new email, network and blackberry accounts) and requests to have insurance policies changes to allow any of the above employees to drive government vehicles (and any associated costs to make these insurance policy changes" =>
    "Records related to Premier designate Frank Coleman and his transition team (including Bill Matthews and Carmel Turpin) including a full list of the people on the transition team, their positions and remuneration levels, copies of all staffing action requests (including, but not limited to, permanent, temporary, any other hire contracts and position changes), OCIO requests (including requests for new email, network and blackberry accounts), security IDs, and requests to have insurance policies changes to allow any of the above employees to drive government vehicles (and any associated costs to make these insurance policy changes",
  }

  def initialize(*args)
    super
    @download_store = DownloadStore.new(File.expand_path(File.join('downloads', 'ca_nl'), Dir.pwd))
  end

  def normalize_abstract(text)
    # Web is generally lower quality than CSV:
    #
    # * uses hyphen instead of n-dash
    # * omits unicode bullets
    # * omits trailing parenthesis
    #
    # CSV has some quality issues:
    #
    # * adds trailing numbers
    # * uses incorrect curly quotes
    # * omits alphanumeric bullets
    # * omits period in "etc."
    # * omits trailing period
    # * omits semi-colons
    #
    # Neither uses curly quotes consistently.
    text.gsub(/\p{Space}+/, ' ').strip.
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

      # Web is generally lower quality than CSV:
      #
      # * adds trailing question marks
      # * "?" or simple quotation mark instead of curly quotation mark
      # * double-hyphen instead of m-dash
      # * "?" instead of hyphen
      # * no space after a semi-colon
      # * inconsistent ampersands

      abstract = tds[1].text.gsub(/\p{Space}+/, ' ').strip.
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
    collection.find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
      if response['media_type']
        path = "#{response.fetch('id')}#{MEDIA_TYPES[response['media_type']]}"
      elsif !download_store.glob("#{response.fetch('id')}.*").empty?
        http_response = client.head(response.fetch('download_url'))
        response['media_type'] = http_response.headers.fetch('content-type')
        path = "#{response.fetch('id')}#{MEDIA_TYPES[response['media_type']]}"
      else
        http_response = client.get(response.fetch('download_url'))
        response['media_type'] = http_response.headers.fetch('content-type')
        path = "#{response.fetch('id')}#{MEDIA_TYPES[response['media_type']]}"

        if MEDIA_TYPES.key?(response['media_type'])
          download_store.write(path, http_response.body)
        else
          error("unrecognized media type: #{response['media_type']}")
        end
      end

      calculate_document_size(response, path)

      collection.update_one({_id: response['_id']}, response)
    end
  end

  def reconcile
    # Identifiers may change year from one system to another, and not always in
    # the same direction. It's unclear which is correct.

    # The order of the keys should be the same as in the schema.
    keys = [
      'id',
      'division_id',
      'identifier',
      'alternate_identifier',
      'abstract',
      'organization',
      'application_fee',
      'processing_fee',
      'date',
      'decision',
      'byte_size',
      'number_of_pages',
      'number_of_rows',
      'documents',
    ]

    summaries = File.expand_path(File.join('summaries'), Dir.pwd)

    web = {}
    duplicates = 0
    collection.find(division_id: DIVISION_ID).each do |response|
      if WEB_DUPLICATES.include?(response['id'])
        duplicates += 1
      else
        # Ignore calculated attributes.
        response = response.except('_id', '_type', 'created_at', 'updated_at')
        identifiers = response['identifier'].strip.scan(%r{[A-Z]{2,5}/\d{1,2}/\d{4}})

        identifiers.each do |identifier|
          key = identifier[0..-2]
          web[key] ||= []

          other = web[key].find do |other|
            # Web has duplicates, the only difference being the download URL. Ignore calculated attributes.
            other.except('id', 'download_url', 'media_type', 'byte_size', 'number_of_pages') == response.except('id', 'download_url', 'media_type', 'byte_size', 'number_of_pages')
          end

          if other && download_store.sha1("#{other['id']}.pdf") == download_store.sha1("#{response['id']}.pdf")
            duplicates += 1
          else
            web[key] << response.merge('identifier' => identifier)
          end
        end

        assert("unrecognized identifier: #{response['identifier']}"){identifiers.any?}
      end
    end

    records = []
    unreconciled_from_csv = []
    JSON.load(File.read(File.join(summaries, 'ca_nl.json'))).each do |csv_response|
      key = csv_response['identifier'].strip[0..-2].
        # Typo in CSV.
        sub(/\ABTCTD/, 'BTCRD')

      web_response = nil
      web_responses = web[key]

      if web_responses
        web_response = web_responses.find do |web_response|
          web_abstract = normalize_abstract(web_response.fetch('abstract'))
          csv_abstract = normalize_abstract(csv_response.fetch('abstract'))
          WEB_ABSTRACTS_MAP.fetch(web_abstract, web_abstract) == CSV_ABSTRACTS_MAP.fetch(csv_abstract, csv_abstract) &&
          normalize_organization(web_response.fetch('organization')) == normalize_organization(csv_response.fetch('organization')) ||
          WEB_BAD_ABSTRACTS.include?(web_response['identifier']) && web_response['identifier'] == csv_response['identifier']
        end
      end

      if web_response
        web_responses.delete(web_response)
        web.delete(key) if web_responses.empty?

        document = {
          'type' => 'disclosure',
          'media_type' => web_response['media_type'],
          'byte_size' => web_response['byte_size'],
        }

        record = csv_response
        # The CSV doesn't have `id`.
        record['id'] = web_response['id']
        # Identifiers are sometimes inconsistent across systems.
        unless csv_response['identifier'] == web_response['identifier']
          record['alternate_identifier'] = web_response['identifier']
        end
        # CSV has the date of decision. Web has the date of publication.
        record['date'] = web_response['date']
        # The CSV doesn't have `byte_size`.
        record['byte_size'] = web_response['byte_size']
        # The number of pages is incorrect for about one in ten rows in the CSV.
        if web_response['number_of_pages']
          record['number_of_pages'] = web_response['number_of_pages']
          document['number_of_pages'] = web_response['number_of_pages']
        end
        # The CSV doesn't have `number_of_rows`.
        if web_response['number_of_rows']
          record['number_of_rows'] = web_response['number_of_rows']
          document['number_of_rows'] = web_response['number_of_rows']
        end

        record['documents'] = [document]
      else
        if web_responses
          message = []

          # Unreconciled records will be unchanged.
          formatted = format_response(csv_response)
          web_responses.each_with_index do |web_response,i|
            format_response(web_response).each_with_index do |web_value,j|
              csv_value = formatted[j]
              unless web_value == csv_value
                csv_value_to_print = i.zero? ? csv_value : []
                [web_value.size, csv_value_to_print.size].max.times do |n|
                  message << "%-#{COLUMN_WIDTH}s  %s" % [csv_value_to_print[n], web_value[n]]
                end
              end
            end
          end

          warn("#{csv_response['identifier']}\n#{message.join("\n")}")
        end

        record = csv_response
        unreconciled_from_csv << record
      end

      records << record.slice(*keys)
    end

    # CSV has some records not on web and vice versa.
    unreconciled_from_web = web.values.flatten
    records += unreconciled_from_web.map{|response| response.slice(*keys)}
    records = sort_records(records)

    # Write the records.
    File.open(File.join(summaries, 'ca_nl.json'), 'w') do |f|
      f << JSON.pretty_generate(records)
    end
    keys -= ['documents']
    CSV.open(File.join(summaries, 'ca_nl.csv'), 'w') do |csv|
      csv << keys
      records.each do |record|
        csv << keys.map{|key| record[key]}
      end
    end

    info("Ignored #{duplicates} duplicates")
    timestamp = (Time.now - 45 * 86400).strftime('%Y-%m-%d')
    recent, old = unreconciled_from_web.partition{|response| response['date'] > timestamp}
    nothing, something = unreconciled_from_csv.partition{|response| response['decision'] == 'nothing disclosed'}
    info("Added #{unreconciled_from_web.size} unreconciled records from web (#{recent.size} recent, #{old.size} old)")
    debug(JSON.pretty_generate(old)) if old.any?
    info("Added #{unreconciled_from_csv.size} unreconciled records from CSV (#{nothing.size} not disclosed, #{something.size} disclosed)")
    debug(JSON.pretty_generate(something)) if something.any?
  end
end

NL.add_scraping_task(:responses)

runner = Pupa::Runner.new(NL)
runner.add_action(name: 'download', description: 'Download responses')
runner.add_action(name: 'reconcile', description: 'Merge CSV data')
runner.run(ARGV)
