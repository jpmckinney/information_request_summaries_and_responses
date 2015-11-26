# Information Request Summaries and Responses

All government bodies in Canada are subject to some freedom of information statutes. Some bodies publish summaries of completed information requests. Fewer publish responses to completed information requests. This repository contains scripts for aggregating what is available.

## Scripts

Search for datasets across multiple catalogs with Namara.io:

    query="freedom of information" rake datasets:search

Download summaries:

    rake datasets:download

Normalize summaries:

    rake datasets:normalize

Normalize one jurisdiction:

    jurisdiction=ca rake datasets:normalize

### Canada

Get the alternate names of organizations to make corrections:

    rake ca:federal_identity_program > support/federal_identity_program.yml

Get the abbreviations of organizations to match across datasets:

    rake ca:abbreviations > support/abbreviations.yml

Get organizations' emails from the coordinators page:

    rake ca:emails:coordinators_page > support/emails_coordinators_page.yml

Get organizations' emails from the search page:

    rake ca:emails:search_page > support/emails_search_page.yml

Compare organizations' emails from different sources:

    rake ca:emails:compare

Construct the URL of the web form of each summary:

    rake ca:urls:get > support/urls.yml

Compare the constructed URLs to the search page's URLs:

    rake ca:urls:validate

Build a histogram of number of summaries per organization:

    rake ca:histogram

### British Columbia

Download the metadata for responses:

    ruby ca_bc_scraper.rb

[openinfo.bc.ca](http://www.openinfo.gov.bc.ca) sometimes redirects to another page then back to the original page which then returns HTTP 200. However, the cache has already stored a HTTP 302 response for the original page; the script therefore reaches a redirect limit. If a `FaradayMiddleware::RedirectLimitReached` error occurs, it is simplest to temporarily move the `_cache` directory. To avoid losing time due to a late error, it is best to scrape and import one month at a time.

    for month in {7..12}; do echo 2011-$month; ruby ca_bc_scraper.rb -q -- date 2011-$month; done
    for year in {2012..2014}; do for month in {1..12}; do echo $year-$month; ruby ca_bc_scraper.rb -q -- date $year-$month; done; done
    for month in {1..11}; do echo 2015-$month; ruby ca_bc_scraper.rb -q -- date 2015-$month; done

Download the attachments for responses (over 40 GB as of late 2015):

    ruby ca_bc_scraper.rb -a download --no-cache

Calculate the number of pages disclosed:

    ruby ca_bc_scraper.rb -a number_of_pages

### Newfoundland and Labrador

Download the metadata for responses:

    ruby ca_nl_scraper.rb

Download the attachments for responses:

    ruby ca_nl_scraper.rb -a download

### Ontario

#### Toronto

Convert the Excel files to CSV files:

    rake ca_on_toronto:excel_to_csv

Stack the CSV files:

    rake ca_on_toronto:stack

## Reference

<dl>
<dt><a href="/data/statutes.csv">statutes.csv</a></dt>
<dd>The names and URLs of all current freedom of information statutes in Canada.</dd>
<dt><a href="/data/keywords.csv">keywords.csv</a></dt>
<dd>The keywords used to refer to freedom of information in Canada.</dd>
</dl>

### Resources

Ratings:

* [Centre for Law and Democracy's Canadan RTI Rating](http://www.law-democracy.org/live/global-rti-rating/canadian-rti-rating/) (federal, provincial, territorial)
* [Newspapers Canada's FOI Audit](http://www.newspaperscanada.ca/FOI) (federal, provincial, territorial, municipal)
* [Global Right to Information Rating](http://www.rti-rating.org/) (federal)

Policies:

* [Criteria for posting summaries of completed access to information requests](http://www.tbs-sct.gc.ca/pol/doc-eng.aspx?section=text&id=18310#appE)
* [Best Practices for Posting Summaries of Completed Access to Information Requests](http://www.tbs-sct.gc.ca/atip-aiprp/tools/bppscair-pepsdaic-eng.asp)

## Nomenclature

In terms of the prevalence of FOI versus ATI:

* 7 jurisdictions have a Freedom of Information and Protection of Privacy Act (AB, BC, MB, NS, ON, PE, SK)
* 4 Access to Information and Protection of Privacy Act (NL, NT, NU, YT)
* 1 Access to Information Act (Canada)
* 1 Right to Information and Protection of Privacy Act (NB)
* 1 An Act respecting Access to Documents Held by Public Bodies and the Protection of Personal Information (QC)

In other words, use whatever term you prefer.

Copyright (c) 2015 James McKinney, released under the MIT license
