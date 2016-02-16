# export AWS_BUCKET=… AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=…
bundle exec rake datasets:download

open http://www.openinfo.gov.bc.ca/
ruby ca_bc_scraper.rb -q -- date `date +%Y-%m`
ruby ca_bc_scraper.rb -a download --no-cache
ruby ca_bc_scraper.rb -a compress
prefix=`date -v15d -v-1m +%Y-%m` ruby_ca_bc_scraper.rb -a upload

ruby ca_nl_scraper.rb
ruby ca_nl_scraper.rb -a download --no-cache
ruby ca_nl_scraper.rb -a compress
prefix=`date -v15d -v-1m +%Y-%m` ruby_ca_nl_scraper.rb -a upload

ruby ca_ns_halifax_scraper.rb
ruby ca_on_markham_scraper.rb
ruby ca_on_markham_scraper.rb -a download --no-cache
ruby ca_on_ottawa_scraper.rb
rake ca_on_toronto:excel_to_csv ca_on_toronto:stack
rake ca_on_waterloo_region:excel_to_csv ca_on_waterloo_region:stack

# ca: 2 (thin records)
# ca_bc: 4 (404s)
# ca_on_burlington: 2 (thin records)
# ca_on_greater_sudbury: 1 (multiple decisions)
rake datasets:normalize
# 1 warning
# 6 duplicates
# 39 recent, 18 old
# 32 not disclosed, 2 disclosed
ruby ca_nl_scraper.rb -v -a reconcile
# ca_bc: 17
# ca_nl: 3
# ca_on_toronto: 1
rake datasets:validate:values
rake datasets:validate:datasets
rake cron:upload

rake ca:federal_identity_program > support/federal_identity_program.yml
rake ca:abbreviations > support/abbreviations.yml
rake ca:emails:coordinators_page > support/emails_coordinators_page.yml # 46 warnings
rake ca:emails:search_page > support/emails_search_page.yml # 13 warnings
rake ca:emails:compare > support/mismatches.csv
# rake ca:urls:get > support/urls.yml
# rake ca:urls:validate
# rake ca:histogram
