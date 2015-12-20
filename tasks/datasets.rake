namespace :datasets do
  # #records_from_source
  def ca_bc_normalize
    connection = Mongo::Client.new(['localhost:27017'], database: 'pupa')
    connection['information_responses'].find(division_id: 'ocd-division/country:ca/province:bc')
  end

  def ca_ns_halifax_normalize
    connection = Mongo::Client.new(['localhost:27017'], database: 'pupa')
    connection['information_responses'].find(division_id: 'ocd-division/country:ca/csd:1209034')
  end

  # #records_from_source
  def normalize_decision(text)
    if text
      text = text.downcase.
        gsub(RE_PARENTHETICAL_CITATION, '').
        gsub(RE_PARENTHETICAL, '').
        gsub(/[\p{Punct}￼]/, ' '). # special character
        gsub(/\p{Space}+/, ' ').strip

      unless text[RE_INVALID]
        RE_DECISIONS.find{|_,pattern| text[pattern]}.first
      end
    end
  end

  # #records_from_source
  def validator
    @validator ||= JSON::Validator.new(JSON.load(File.read(File.join('schemas', 'summary.json'))), {}, {
      clear_cache: false,
      parse_data: false,
    })
  end

  def records_from_source(directory, template, options = {})
    records = []

    method = "#{directory}_normalize"

    if NON_CSV_SOURCES.include?(directory)
      rows = send(method)
    else
      filename = File.join('wip', directory, 'data.csv')

      unless File.exist?(filename)
        filenames = Dir[File.join('wip', directory, '*.csv')]
        filename = filenames[0]
        assert("#{directory}: can't determine CSV file"){filenames.one?}
      end

      begin
        rows = send(method, File.read(filename))
      rescue NoMethodError
        csv_options = {headers: true}
        if CSV_ENCODINGS.key?(directory)
          csv_options[:encoding] = CSV_ENCODINGS[directory]
        end
        rows = CSV.foreach(filename, csv_options)
      end
    end

    normalize = options.fetch(:normalize, true)
    validate = options.fetch(:validate, true)
    renderer = WhosGotDirt::Renderer.new(template)

    rows.each_with_index do |row,index|
      # ca_on_greater_sudbury has rows with only an OBJECTID.
      if row.to_h.except('OBJECTID').values.any?
        begin
          record = renderer.result(row.to_h)

          if normalize
            record['decision'] = normalize_decision(record['decision'])
            record.delete('decision') unless record['decision']
          end

          if validate
            validator.instance_variable_set('@errors', [])
            validator.instance_variable_set('@data', record)
            validator.validate
          end
          records << record
        rescue => e
          puts "#{directory} #{index + 2}: #{e}\n  #{record}"
        end
      end
    end

    records
  end

  desc 'Searches Namara.io for datasets'
  task :search do
    query = ENV['query']

    assert('usage: bundle exec rake namara <query>'){query}

    ignore = [
      'Cybertech_Systems_&_Software',
      'North_American_Cartographic_Information_Society',
      'OpenDataDC',
    ]
    ignore_re = /\AUS(?:[_-]|\z)|\A#{ignore.join('|')}\z/

    page = 1
    begin
      response = client.get do |request|
        request.url "https://api.namara.io/v0/data_sets?search[query]=#{CGI.escape(query)}&search[page]=#{page}"
        request.headers['Accept'] = 'application/json'
      end
      response.body['data_sets'].each do |dataset|
        key = dataset['source']['key']
        if key[/\ACA\b/]
          dataset['data_set_metas'].each_with_index do |meta,index|
            url = meta.fetch('page_url') || dataset['data_resources'][index].fetch('url')
            puts "#{meta.fetch('title')[0, 60].ljust(60)} #{url}"
          end
        elsif !key[ignore_re]
          p key
        end
      end
      page += 1
    end until response.body['data_sets'].empty?
  end

  desc 'Downloads datasets'
  task :download do
    # @see https://docs.google.com/spreadsheets/d/1WQ6kWL5hAEThi31ZQtTZRX5E8_Y9BwDeEWATiuDakTM/edit#gid=0
    datasets = {
      # http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c
      'ca' => 'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
      # http://opendata.gov.nl.ca/public/opendata/page/?page-id=datasetdetails&id=222
      'ca_nl' => 'http://opendata.gov.nl.ca/public/opendata/filedownload/?file-id=4383',
      # http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0
      'ca_on_burlington' => 'http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0.csv',
      # http://opendata.greatersudbury.ca/datasets/5a7bb9da5c7d4284a9f7ea5f6e8e9364_0
      'ca_on_greater_sudbury' => 'http://opendata.greatersudbury.ca/datasets/5a7bb9da5c7d4284a9f7ea5f6e8e9364_0.csv',
    }

    paths = {
      'wip' => 'wip',
    }
    datasets.each do |directory,_|
      paths[directory] = File.join(paths['wip'], directory)
    end

    paths.each do |_,path|
      FileUtils.mkdir_p(path)
    end

    datasets.each do |directory,url|
      if url
        basename = File.extname(url) == '.csv' ? File.basename(url) : 'data.csv'
        File.open(File.join(paths[directory], basename), 'w') do |f|
          f.write(client.get(url).body)
        end
      end
    end
  end

  desc 'Normalizes datasets'
  task :normalize do
    if ENV['jurisdiction']
      templates = TEMPLATES.slice(ENV['jurisdiction'])
    else
      templates = TEMPLATES
    end

    templates.each do |directory,template|
      records = sort_records(records_from_source(directory, template))

      # Write the records.
      FileUtils.mkdir_p('summaries')
      File.open(File.join('summaries', "#{directory}.json"), 'w') do |f|
        f << JSON.pretty_generate(records)
      end
      CSV.open(File.join('summaries', "#{directory}.csv"), 'w') do |csv|
        csv << template.keys
        records.each do |record|
          csv << template.keys.map{|key| record[key]}
        end
      end
    end
  end

  desc 'Validates datasets'
  task :validate do
    no_pages = [
      'abandoned',
      'in progress',
      'nothing disclosed',
      'transferred',
      'treated informally',
    ]
    messages = [
      'number_of_pages should be equal to zero',
      'number_of_pages should be greater than zero',
    ]

    Dir[File.join('summaries', '*.json')].each do |path|
      directory = File.basename(path, '.json')
      records = records_from_source(directory, TEMPLATES[directory], normalize: false, validate: false)
      counts_by_decision = {}
      examples_by_decision = {}

      JSON.load(File.read(path)).each do |record|
        if record['number_of_pages'] && record['decision'] && record['decision'] != 'correction'
          if record['number_of_pages'] > 0 && no_pages.include?(record['decision']) || record['number_of_pages'] == 0 && !no_pages.include?(record['decision'])
            # NL publishes letters of 6 pages or less if nothing disclosed.
            unless record['division_id'] == 'ocd-division/country:ca/province:nl' && record['number_of_pages'] <= 6 && record['decision'] == 'nothing disclosed'
              decisions = records.select do |r|
                if record['id']
                  r['id'] == record['id']
                else
                  r['identifier'] == record['identifier'] && r['organization'] == record['organization']
                end
              end.map do |match|
                match['decision']
              end

              decisions.each do |decision|
                counts_by_decision[record['decision']] ||= Hash.new(0)
                counts_by_decision[record['decision']][decision] += 1

                examples_by_decision[decision] ||= []
                examples_by_decision[decision] << record.slice('id', 'identifier', 'organization').values
              end
            end
          end
        end
      end

      if counts_by_decision.any?
        puts directory
        counts_by_decision.partition{|decision,_| no_pages.include?(decision)}.each_with_index do |partition,index|
          puts "  #{messages[index]}"
          partition.each do |decision,counts|
            puts "    #{decision}"
            counts.sort_by{|_,v| -v}.each do |text,count|
              puts '      %2d %s' % [count, text]
              examples_by_decision[text].each do |example|
                puts "         #{example.join(' ')}"
              end
            end
          end
        end
      end
    end
  end
end
