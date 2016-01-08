# Information Request Summaries and Responses

All government bodies in Canada are subject to some freedom of information statutes. Some bodies publish summaries of completed information requests. Fewer publish responses to completed information requests. This repository contains scripts for aggregating what is available.

## Dependencies

    brew install media-info libtiff poppler
    sudo PIP_REQUIRE_VIRTUALENV=false pip install csvkit

See also the dependencies of [docsplit](https://documentcloud.github.io/docsplit/) and [pdfshaver](https://github.com/documentcloud/pdfshaver). (You may need to use [this Homebrew formula](https://github.com/jpmckinney/homebrew/blob/pdfium/Library/Formula/pdfium.rb) for PDFium (see the [PR](https://github.com/knowtheory/homebrew/pull/1).)

## Scripts

Search for new datasets across multiple catalogs with Namara.io:

    query="freedom of information" rake datasets:search

Download summaries:

    rake datasets:download

Or, download one jurisdiction:

    jurisdiction=ca rake datasets:download

Run the [British Columbia](#british-columbia), [Newfoundland and Labrador](#newfoundland-and-labrador), [Halifax](#halifax), [Toronto](#toronto) and [Waterloo Region](#waterloo_region) scripts.

Normalize summaries:

    rake datasets:normalize

Or, normalize one jurisdiction:

    jurisdiction=ca rake datasets:normalize

Reconcile NL's scraped data with its open data:

    ruby ca_nl_scraper.rb -v -a reconcile

Validate values according to jurisdiction-specific rules:

    rake datasets:validate:values

Validate that the decision and the number of pages agree:

    rake datasets:validate:datasets

### Canada

*The following scripts are only relevant to automating informal requests for disclosed records from Canada.*

Get the alternate names of organizations to make corrections:

    rake ca:federal_identity_program > support/federal_identity_program.yml

Get the abbreviations of organizations to match across datasets:

    rake ca:abbreviations > support/abbreviations.yml

Get organizations' emails from the [coordinators page](http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/atip-aiprp/coord-eng.asp):

    rake ca:emails:coordinators_page > support/emails_coordinators_page.yml

Get organizations' emails from the [search page](http://open.canada.ca/en/search/ati):

    rake ca:emails:search_page > support/emails_search_page.yml

Compare organizations' emails from different sources:

    rake ca:emails:compare > support/mismatches.csv

Construct the URL of the web form of each summary:

    rake ca:urls:get > support/urls.yml

Compare the constructed URLs to the search page's URLs:

    rake ca:urls:validate

Build a histogram of number of summaries per organization:

    rake ca:histogram

### British Columbia

**Note:** British Columbia sometimes publishes an incorrect file size. We therefore calculate the correct value.

Download the metadata for responses:

    ruby ca_bc_scraper.rb

[openinfo.bc.ca](http://www.openinfo.gov.bc.ca) sometimes redirects to another page then back to the original page which then returns HTTP 200. However, the cache has already stored a HTTP 302 response for the original page; the script therefore reaches a redirect limit. If a `FaradayMiddleware::RedirectLimitReached` error occurs, it is simplest to temporarily move the `_cache` directory. To avoid losing time due to a late error, it is best to scrape and import one month at a time.

    for month in {7..12}; do echo 2011-$month; ruby ca_bc_scraper.rb -q -- date 2011-$month; done
    for year in {2012..2014}; do for month in {1..12}; do echo $year-$month; ruby ca_bc_scraper.rb -q -- date $year-$month; done; done
    for month in {1..11}; do echo 2015-$month; ruby ca_bc_scraper.rb -q -- date 2015-$month; done

Download the attachments for responses (over 40 GB as of late 2015):

    ruby ca_bc_scraper.rb -a download --no-cache

Determine which attachments definitely require OCR:

    ruby ca_bc_scraper.rb -a compress

Upload the attachments as archives to S3:

    AWS_BUCKET=… AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… ruby_ca_bc_scraper.rb -a upload

### Newfoundland and Labrador

**Note:** Newfoundland and Labrador publishes an incorrect number of pages for about one in ten files. We therefore calculate the correct value.

Download the metadata for responses:

    ruby ca_nl_scraper.rb

Download the attachments for responses:

    ruby ca_nl_scraper.rb -a download --no-cache

Determine which attachments definitely require OCR:

    ruby ca_nl_scraper.rb -a compress

Upload the attachments as archives to S3:

    AWS_BUCKET=… AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… ruby_ca_nl_scraper.rb -a upload

### Nova Scotia

#### Halifax

Download summaries:

    ruby ca_ns_halifax_scraper.rb

### Ontario

#### Toronto

Download the Excel files:

    rake ca_on_toronto:download

Convert the Excel files to CSV files:

    rake ca_on_toronto:excel_to_csv

Stack the CSV files:

    rake ca_on_toronto:stack

### Waterloo Region

Download the Excel files:

    rake ca_on_waterloo_region:download

Convert the Excel files to CSV files:

    rake ca_on_waterloo_region:excel_to_csv

Stack the CSV files:

    rake ca_on_waterloo_region:stack

## Adding a new jurisdiction

* If the source is CSV, add the source URL and data URL to `DATASET_URLS`.
* If the source is HTML, add the jurisdiction to `NON_CSV_SOURCES`.
* Run `rake datasets:download`.
* Inspect the data in `wip`, and add an entry to `TEMPLATES`.
* Run `rake datasets:normalize`.
* Inspect the messages, and update `RE_INVALID` and `RE_DECISIONS`.
* Inspect the data in `summaries`, and add an entry to `datasets:validate:values`.
* Run `rake datasets:validate:values` and make corrections if necessary.
* Add an entry to `identifiers.md`.
* Add any jurisdiction-specific [scripts](#scripts) or [notes](#notes) to this readme.

## Notes

This project does not publish all data elements published by jurisdictions, primarily because they are of low value, hard to normalize, or unique to a jurisdiction.

* Newfoundland and Labrador: comments, footnotes
* Burlington: exemptions, time to complete
* Greater Sudbury: status, time to complete, notice of extension, notice to affected party, exemptions, appeal number
* Edmonton: status

## Reference

<dl>
<dt><a href="/reference/statutes.csv">statutes.csv</a></dt>
<dd>The names and URLs of all current freedom of information statutes in Canada.</dd>
<dt><a href="/reference/keywords.csv">keywords.csv</a></dt>
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

### Nomenclature

In terms of the prevalence of FOI versus ATI:

* 7 jurisdictions have a Freedom of Information and Protection of Privacy Act (AB, BC, MB, NS, ON, PE, SK)
* 4 Access to Information and Protection of Privacy Act (NL, NT, NU, YT)
* 1 Access to Information Act (Canada)
* 1 Right to Information and Protection of Privacy Act (NB)
* 1 An Act respecting Access to Documents Held by Public Bodies and the Protection of Personal Information (QC)

In other words, use whatever term you prefer.

Copyright (c) 2015 James McKinney, released under the MIT license
