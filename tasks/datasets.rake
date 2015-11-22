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
      'summaries' => 'summaries',
    }
    datasets.each do |directory,_|
      paths[directory] = File.join(paths['summaries'], directory)
    end

    paths.each do |_,path|
      unless Dir.exist?(path)
        Dir.mkdir(path)
      end
    end

    datasets.each do |directory,url|
      if url
        basename = File.extname(url) == '.csv' ? File.basename(url) : 'data.csv'
        File.open(File.join(paths[directory], basename), 'w') do |f|
          f.write(client.get(url).body)
        end
      end
    end

    # url = 'http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD'
    # client.get(url).body.xpath('//div[@class="panel-body"]//@href').each do |href|
    #   path = href.value
    #   File.open(File.join(paths['ca_on_toronto'], File.basename(path)), 'w') do |f|
    #     f.write(client.get("http://www1.toronto.ca#{URI.escape(path)}").body)
    #   end
    # end
  end
end
