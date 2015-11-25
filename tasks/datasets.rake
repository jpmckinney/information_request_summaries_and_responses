namespace :datasets do
  desc 'Search Namara.io for datasets'
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

  desc 'Download datasets'
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
      # http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD
      'ca_on_toronto' => nil,
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

    url = 'http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD'
    client.get(url).body.xpath('//div[@class="panel-body"]//@href').each do |href|
      path = href.value
      File.open(File.join(paths['ca_on_toronto'], File.basename(path)), 'w') do |f|
        f.write(client.get("http://www1.toronto.ca#{URI.escape(path)}").body)
      end
    end
  end

  desc 'Normalize datasets'
  task :normalize do
    schema = JSON.load(File.read(File.join('schemas', 'summary.json')))

    validator = JSON::Validator.new(schema, {}, {
      clear_cache: false,
      parse_data: false,
    })

    encodings = {
      'ca_nl' => 'iso-8859-1',
    }

    templates = {
      'ca' => {
        'identifier' => '/Request Number ~1 Numero de la demande',
        'date' => lambda{|data|
          year = JsonPointer.new(data, '/Year ~1 Année').value
          month = JsonPointer.new(data, '/Month ~1 Mois (1-12)').value
          ['date', "#{year}-#{month.sub(/\A(?=\d\z)/, '0')}"]
        },
        'abstract' => '/English Summary ~1 Sommaire de la demande en anglais',
        'decision' => '/Disposition',
        'organization' => '/Org',
        'number_of_pages' => lambda{|data|
          v = JsonPointer.new(data, '/Number of Pages ~1 Nombre de pages').value
          ['number_of_pages', Integer(v)]
        },
      },
      'ca_nl' => {
        'identifier' => '/Request Number',
        'date' => lambda{|data|
          year = JsonPointer.new(data, '/Year').value
          month = JsonPointer.new(data, '/Month').value
          year_month = JsonPointer.new(data, '/Month Name').value
          if month
            ['date', "#{year}-#{month.sub(/\A(?=\d\z)/, '0')}"]
          else
            ['date', Date.strptime(year_month, '%y-%b').strftime('%Y-%m')]
          end
        },
        'abstract' => '/Summary of Request',
        'decision' => '/Outcome of Request',
        'organization' => '/Department',
        'number_of_pages' => lambda{|data|
          v = JsonPointer.new(data, '/Number of Pages').value
          ['number_of_pages', v == 'EXCEL' ? nil : Integer(v)]
        },
      },
      'ca_on_burlington' => {
        'identifier' => '/No.',
        'date' => '/Year',
        'decision' => '/Decision',
        'organization' => '/Dept Contact',
        'classification' => lambda{|data|
          v = JsonPointer.new(data, '/Request Type').value
          case v
          when 'General Records'
            ['classification', 'general']
          when 'Personal Information'
            ['classification', 'personal']
          else
            raise "unrecognized classification: #{v}" if v
          end
        },
      },
      'ca_on_greater_sudbury' => {
        'identifier' => '/FILE_NUMBER',
        'date' => lambda{|data|
          v = JsonPointer.new(data, '/NOTICE_OF_DECISION_SENT').value
          ['date', v && (Date.strptime(v, '%m/%d/%Y') rescue Date.strptime(v, '%d/%m/%Y')).strftime('%Y-%m-%d')]
        },
        'abstract' => '/PUBLIC_DESCRIPTION',
        'decision' => lambda{|data|
          v = [
            '1_ALL_INFORMATION_DISCLOSED',
            '2_INFORMATION_DISCLOSED_IN_PART',
            '3_NO_INFORMATION_DISCLOSED',
            '4_NO_RESPONSIVE_RECORD_EXIST',
            '5_REQUEST_WITHDRAWN,_ABANDONED_OR_NON-JURISDICTIONAL',
          ].find do |header|
            JsonPointer.new(data, "/#{header}").value
          end
          ['decision', v]
        },
        'organization' => '/DEPARTMENT',
        'classification' => lambda{|data|
          v = JsonPointer.new(data, '/PERSONAL_OR_GENERAL').value
          ['classification', v.downcase.strip]
        },
      },
      'ca_on_toronto' => {
        'identifier' => '/Request_Number',
        'date' => lambda{|data|
          v = JsonPointer.new(data, '/Decision_Communicated').value
          ['date', v && (Date.strptime(v, '%d-%m-%Y') rescue Date.strptime(v, '%Y-%m-%d')).strftime('%Y-%m-%d')]
        },
        'abstract' => '/Summary',
        'decision' => '/Name',
        'number_of_pages' => lambda{|data|
          v = JsonPointer.new(data, '/Number_of_Pages_Released').value
          ['number_of_pages', v && Integer(v.sub(/\.0\z/, ''))]
        },
        'classification' => lambda{|data|
          v = JsonPointer.new(data, '/Request_Type').value
          case v
          when 'General Records'
            ['classification', 'general']
          when 'Personal Information', 'Personal Health Information', 'Correction of Personal Information'
            ['classification', 'personal']
          else
            raise "unrecognized classification: #{v}"
          end
        },
      },
    }

    if ENV['directory']
      templates = templates.slice(ENV['directory'])
    end

    templates.each do |directory,template|
      wip = File.join('wip', directory)
      filename = File.join(wip, 'data.csv')
      renderer = WhosGotDirt::Renderer.new(template)

      # Find the CSV to normalize.
      unless File.exist?(filename)
        filenames = Dir[File.join(wip, '*.csv')]
        filename = filenames[0]
        assert("#{directory}: can't determine CSV file"){filenames.one?}
      end

      # Set the CSV options.
      options = {headers: true}
      if encodings.key?(directory)
        options[:encoding] = encodings[directory]
      end

      # Normalize the records.
      records = []
      CSV.foreach(filename, options).with_index do |row,index|
        # ca_on_greater_sudbury has rows with only an OBJECTID.
        if row.to_h.except('OBJECTID').values.any?
          begin
            record = renderer.result(row.to_h)
            validator.instance_variable_set('@errors', [])
            validator.instance_variable_set('@data', record)
            validator.validate
            records << record
          rescue => e
            raise "#{directory} #{index + 1}: #{e}"
          end
        end
      end

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
end
