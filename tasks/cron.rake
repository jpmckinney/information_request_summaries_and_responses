namespace :cron do
  desc 'Upload CSVs to S3'
  task :upload do
    store = AWSStore.new('information_requests', ENV['AWS_BUCKET'], ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])

    DATASET_URLS.each do |directory,url|
      basename = File.extname(url) == '.csv' ? File.basename(url) : 'data.csv'
      store.write(File.join(Time.now.utc.year, Time.now.utc.strftime('%Y-%m-%d'), directory, basename), client.get(url).body)
    end
  end
end
