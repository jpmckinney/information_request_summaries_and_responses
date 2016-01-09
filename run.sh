# export AWS_BUCKET=… AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=…
rake datasets:download
ruby ca_bc_scraper.rb -q -- date `date +%Y-%m`
ruby ca_bc_scraper.rb -a download --no-cache
ruby ca_bc_scraper.rb -a compress
ruby_ca_bc_scraper.rb -a upload
ruby ca_nl_scraper.rb
ruby ca_nl_scraper.rb -a download --no-cache
ruby ca_nl_scraper.rb -a compress
prefix=2016 ruby_ca_nl_scraper.rb -a upload
ruby ca_ns_halifax_scraper.rb
ruby ca_on_markham_scraper.rb
ruby ca_on_ottawa_scraper.rb
rake ca_on_toronto:download ca_on_toronto:excel_to_csv ca_on_toronto:stack
rake ca_on_waterloo_region:download ca_on_waterloo_region:excel_to_csv ca_on_waterloo_region:stack
rake datasets:normalize
ruby ca_nl_scraper.rb -v -a reconcile
rake datasets:validate:values
rake datasets:validate:datasets
