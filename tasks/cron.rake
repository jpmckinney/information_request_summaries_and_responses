namespace :cron do
  desc 'Upload CSVs to S3'
  task :upload do
    store = AWSStore.new('information_requests', ENV['AWS_BUCKET'], ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    now = Time.now.utc

    DATASET_URLS.each do |jurisdiction_code,urls|
      urls.each do |url|
        value = client.get(url).body
        shasum = Digest::SHA1.hexdigest(value)
        shasum_filename = "#{jurisdiction_code}.shasum"
        unless store.exist?(shasum_filename) && store.read(shasum_filename) == shasum
          data_filename = url_to_basename(url)
          store.write(File.join(jurisdiction_code, now.strftime('%Y'), now.strftime('%Y-%m-%d'), data_filename), value)
          store.write(shasum_filename, shasum)
        end
      end
    end
  end
end
