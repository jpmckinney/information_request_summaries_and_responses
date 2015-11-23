Get the alternate names of organizations to make corrections:

    rake federal_identity_program > support/federal_identity_program.yml

Get the abbreviations of organizations to match across datasets:

    rake abbreviations > support/abbreviations.yml

Get organizations' emails from the ATI coordinators page:

    rake emails:coordinators_page > support/emails_coordinators_page.yml

Get organizations' emails from the ATI summaries page:

    rake emails:search_page > support/emails_search_page.yml

Compare organizations' emails from different sources:

    rake emails:compare

Construct the URL of the web form of each request:

    rake urls:get > support/urls.yml

Compare the constructed URLs to the ATI summaries page's URLs:

    rake urls:validate

Build a histogram of number of requests per organization:

    rake histogram

Search for datasets across multiple catalogs with Namara.io:

    query="access to information" rake datasets:search

Download ATI summaries from catalogs:

    rake datasets:download

Download the metadata for ATI responses from BC:

    ruby bc_scraper.rb

Download the attachments for ATI responses from BC:

    ruby bc_scraper.rb -a download
