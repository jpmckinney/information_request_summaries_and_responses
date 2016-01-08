namespace :datasets do
  # #records_from_source
  def information_responses(division_id)
    connection = Mongo::Client.new(['localhost:27017'], database: 'pupa')
    connection['information_responses'].find(division_id: division_id)
  end
  def ca_bc_normalize
    information_responses('ocd-division/country:ca/province:bc')
  end
  def ca_ns_halifax_normalize
    information_responses('ocd-division/country:ca/csd:1209034')
  end
  def ca_on_markham_normalize
    information_responses('ocd-division/country:ca/csd:3519036')
  end
  def ca_on_ottawa_normalize
    information_responses('ocd-division/country:ca/csd:3506008')
  end

  # #records_from_source
  def normalize_decision(original)
    if original
      text = original.downcase.
        gsub(RE_PARENTHETICAL_CITATION, '').
        gsub(RE_PARENTHETICAL, '').
        gsub(/[\p{Punct}￼]/, ' '). # special character
        gsub(/\p{Space}+/, ' ').strip

      unless text[RE_INVALID]
        decision, _ = RE_DECISIONS.find{|_,pattern| text[pattern]}
        unless decision
          puts "unrecognized decision #{original.inspect}"
        end
        decision
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

  def records_from_source(jurisdiction_code, template, options = {})
    records = []

    method = "#{jurisdiction_code}_normalize"

    if NON_CSV_SOURCES.include?(jurisdiction_code)
      rows = send(method)
    else
      filename = File.join('wip', jurisdiction_code, 'data.csv')

      unless File.exist?(filename)
        filenames = Dir[File.join('wip', jurisdiction_code, '*.csv')]
        filename = filenames[0]
        assert("#{jurisdiction_code}: can't determine CSV file"){filenames.one?}
      end

      begin
        rows = send(method, File.read(filename))
      rescue NoMethodError => e
        if e.message[method]
          csv_options = {headers: true}
          if CSV_ENCODINGS.key?(jurisdiction_code)
            csv_options[:encoding] = CSV_ENCODINGS[jurisdiction_code]
          end
          rows = CSV.foreach(filename, csv_options)
        else
          raise
        end
      end
    end

    normalize = options.fetch(:normalize, true)
    validate = options.fetch(:validate, true)
    renderer = WhosGotDirt::Renderer.new(template)

    begin
      rows.each_with_index do |row,index|
        # ca_on_greater_sudbury has rows with only an OBJECTID.
        if row.to_h.except('OBJECTID').values.any?
          begin
            record = renderer.result(row.to_h)

            if normalize
              record['decision'] = normalize_decision(record['decision'])
              unless record['decision']
                record.delete('decision')
              end
            end

            if validate
              validator.instance_variable_set('@errors', [])
              validator.instance_variable_set('@data', record)
              validator.validate
            end
            records << record
          rescue JSON::Schema::ValidationError => e
            puts "#{jurisdiction_code} #{index + 2}: #{e}\n  #{record}"
          end
        end
      end
    rescue CSV::MalformedCSVError => e
      puts "#{jurisdiction_code}: #{e.message}"
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
    if ENV['jurisdiction']
      datasets = DATASET_URLS.slice(ENV['jurisdiction'])
    else
      datasets = DATASET_URLS
    end

    paths = {
      'wip' => 'wip',
    }
    datasets.each do |jurisdiction_code,_|
      paths[jurisdiction_code] = File.join(paths['wip'], jurisdiction_code)
    end

    paths.each do |_,path|
      FileUtils.mkdir_p(path)
    end

    datasets.each do |jurisdiction_code,url|
      basename = url_to_basename(url)
      input = File.join(paths[jurisdiction_code], basename)
      File.open(input, 'w') do |f|
        f.write(client.get(url).body)
      end

      unless File.extname(input) == '.csv'
        output = input.sub(/\.xlsx?\z/, '.csv')
        puts "in2csv #{Shellwords.escape(input)} | csvcut -x > #{Shellwords.escape(output)}"
        `in2csv #{Shellwords.escape(input)} | csvcut -x > #{Shellwords.escape(output)}`
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

    templates.each do |jurisdiction_code,template|
      records = sort_records(records_from_source(jurisdiction_code, template))

      # Write the records.
      FileUtils.mkdir_p('summaries')
      File.open(File.join('summaries', "#{jurisdiction_code}.json"), 'w') do |f|
        f << JSON.pretty_generate(records)
      end
      keys = template.keys - ['documents']
      CSV.open(File.join('summaries', "#{jurisdiction_code}.csv"), 'w') do |csv|
        csv << keys
        records.each do |record|
          csv << keys.map{|key| record[key]}
        end
      end
    end
  end

  namespace :validate do
    desc 'Validates values according to jurisdiction-specific rules'
    task :values do
      ca_nl_identifiers = CSV.foreach(File.join('reference', 'ca_nl-organization_identifiers.csv'), headers: true).map do |row|
        row.fetch('identifier')
      end

      identifier_patterns = {
        # ca has multiple identifier patterns.
        'ca_ab_calgary' => ['identifier', /\A\d{4}-[BCFGP]-\d{4}(?:-\d{3})?\z/],
        'ca_ab_edmonton' => ['identifier', /\A\d{4}-\d{4}(?:-\d{3})?\z/],
        'ca_bc' => ['identifier', /\A[A-Z]{3}-\d{4}-\d{5}\z/],
        'ca_nl' => ['identifier', %r{\A(?:#{ca_nl_identifiers.join('|')})/\d{1,2}/\d{4}\z}],
        'ca_ns_halifax' => ['identifier', /\AAR-\d{2}-\d{3}\z/],
        'ca_on_burlington' => ['position', /\A\d{1,2}\z/],
        'ca_on_greater_sudbury' => ['identifier', /\AFOI\d{4}-\d{1,3}\z/],
        'ca_on_markham' => ['identifier', /\A\d{2}-\d{2}\z/],
        'ca_on_ottawa' => ['identifier', /\AA-\d{4}-\d{5}\z/],
        'ca_on_toronto' => ['identifier', /\A(?:AG|AP|COR|PHI)-\d{4}-\d{5}\z/],
        'ca_ab_waterloo_region' => ['identifier', /\A(?:\d{8}|\d{5})\z/],
      }

      Dir[File.join('summaries', '*.json')].each do |path|
        basename = File.basename(path, '.json')
        property, pattern = identifier_patterns[basename]
        if pattern
          values = Set.new
          JSON.load(File.read(path)).each do |record|
            match = record[property].to_s.match(pattern)
            if match
              values += match.captures
            else
              puts "#{basename}: #{record[property].inspect}"
            end
          end
          if values.any?
            puts "#{basename}\n#{values.to_a.join("\n")}\n"
          end
        end
      end

      organization_lists = {
        'ca_bc' => /\A[A-Z]+/,
        'ca_nl' => /\A[A-Z]+/,
      }

      messages = []
      organization_lists.each do |basename,pattern|
        names = {}
        CSV.foreach(File.join('reference', "#{basename}-organization_identifiers.csv"), headers: true) do |row|
          names[row['identifier']] = Set.new(row.fields[1..-1].compact)
        end
        JSON.load(File.read(File.join('summaries', "#{basename}.json"))).each do |record|
          identifier = record['identifier'].match(pattern)[0]
          if names.key?(identifier)
            unless names[identifier].include?(record['organization'])
              messages << "#{basename}: expected #{record['organization'].inspect} to be in #{names.fetch(identifier).to_a} (#{identifier})"
            end
          else
            messages << "#{basename}: unrecognized identifier #{identifier} for #{record['organization'].inspect}"
          end
        end
      end
      puts messages.sort
    end

    desc 'Performs dataset-level validations'
    task :datasets do
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
        jurisdiction_code = File.basename(path, '.json')
        records = records_from_source(jurisdiction_code, TEMPLATES[jurisdiction_code], normalize: false, validate: false)
        counts_by_decision = {}
        examples_by_decision = {}

        JSON.load(File.read(path)).each do |record|
          if record['number_of_pages'] && record['decision'] && record['decision'] != 'correction'
            if record['number_of_pages'] > 0 && no_pages.include?(record['decision']) || record['number_of_pages'] == 0 && !no_pages.include?(record['decision'])
              # NL publishes letters of 6 pages or less if nothing disclosed.
              unless record['division_id'] == 'ocd-division/country:ca/province:nl' && record['number_of_pages'] <= 6 && record['decision'] == 'nothing disclosed'
                # Get the non-normalized decisions.
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
                  examples_by_decision[decision] << record.slice('identifier', 'number_of_pages', 'organization').values
                end
              end
            end
          end
        end

        if counts_by_decision.any?
          puts jurisdiction_code
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
end
