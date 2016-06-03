# Information Request Summaries and Responses

All government bodies in Canada are subject to some freedom of information statutes. Some bodies publish summaries of completed information requests. Fewer publish responses to completed information requests. This repository contains scripts for aggregating what is available.

## Dependencies

    brew install media-info libtiff poppler
    sudo PIP_REQUIRE_VIRTUALENV=false pip install csvkit

See also the dependencies of [docsplit](https://documentcloud.github.io/docsplit/) and [pdfshaver](https://github.com/documentcloud/pdfshaver). You may need to use [this Homebrew formula](https://github.com/jpmckinney/homebrew/blob/pdfium/Library/Formula/pdfium.rb) for PDFium (see [PR](https://github.com/knowtheory/homebrew/pull/1)).

## Scripts

The following scripts should be run in order to collect the dataset.

Download the single-file sources to the `wip/` directory:

    PYTHONWARNINGS=ignore bundle exec rake datasets:download

Or, download one jurisdiction:

    jurisdiction=ca bundle exec rake datasets:download

Run the [British Columbia](#british-columbia), [Newfoundland and Labrador](#newfoundland-and-labrador), and [municipal](#municipalities) scripts to download the multiple-file sources.

Normalize the summaries to the `summaries` directory:

    bundle exec rake datasets:normalize

Or, normalize one jurisdiction:

    jurisdiction=ca bundle exec rake datasets:normalize

Reconcile NL's scraped data with its open data, rewriting its files in the `summaries` directory:

    ruby ca_nl_scraper.rb -v -a reconcile

Validate values according to jurisdiction-specific rules:

    bundle exec rake datasets:validate:values

Validate that the decision and the number of pages agree:

    bundle exec rake datasets:validate:datasets

To find additional sources, search for datasets across multiple catalogs with Namara.io:

    query="freedom of information" rake datasets:search

### British Columbia

**Note:** British Columbia sometimes publishes an incorrect file size. We therefore calculate the correct value.

Download the metadata for responses:

    ruby ca_bc_scraper.rb

[openinfo.bc.ca](http://www.openinfo.gov.bc.ca) sometimes redirects to another page then back to the original page which then returns HTTP 200. However, the cache has already stored a HTTP 302 response for the original page; the script therefore reaches a redirect limit. If a `FaradayMiddleware::RedirectLimitReached` error occurs, it is simplest to temporarily move the `_cache` directory. To avoid losing time due to a late error, it is best to scrape and import one month at a time.

    for month in {7..12}; do echo 2011-$month; ruby ca_bc_scraper.rb -q -- date 2011-$month; done
    for year in {2012..2015}; do for month in {1..12}; do echo $year-$month; ruby ca_bc_scraper.rb -q -- date $year-$month; done; done
    ruby ca_bc_scraper.rb -q -- date `date +%Y-%m`

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

### Municipalities

* **Halifax:** Download summaries:

        ruby ca_ns_halifax_scraper.rb

* **Markham:** Download summaries and documents:

        ruby ca_on_markham_scraper.rb
        ruby ca_on_markham_scraper.rb -a download --no-cache

* **Ottawa:** Download summaries:

        ruby ca_on_ottawa_scraper.rb

### Canada

*The following scripts are only relevant to automating informal requests for disclosed records from Canada.*

Get the alternate names of organizations to make corrections:

    bundle exec rake ca:federal_identity_program > support/federal_identity_program.yml

Get the abbreviations of organizations to match across datasets:

    bundle exec rake ca:abbreviations > support/abbreviations.yml

Get organizations' emails from the [coordinators page](http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/atip-aiprp/coord-eng.asp):

    bundle exec rake ca:emails:coordinators_page > support/emails_coordinators_page.yml

Get organizations' emails from the [search page](http://open.canada.ca/en/search/ati):

    bundle exec rake ca:emails:search_page > support/emails_search_page.yml

Compare organizations' emails from different sources:

    bundle exec rake ca:emails:compare > support/mismatches.csv

Build a histogram of number of summaries per organization:

    bundle exec rake ca:histogram

Construct the URL of the web form of each summary:

    bundle exec rake ca:urls:get > support/urls.yml

Compare the constructed URLs to the search page's URLs:

    bundle exec rake ca:urls:validate

## Adding a new jurisdiction

* If the source is a single CSV or Excel file:
    * Add the source URL and data URL to `DATASET_URLS`
    * Run `rake datasets:download`
    * Inspect the data in `wip`, and add an entry to `TEMPLATES`
* If the source is an HTML file:
    * Add the jurisdiction to `NON_CSV_SOURCES`
    * Write and run a scraper
    * Define a `*_normalize` method
* Run `rake datasets:normalize` and make corrections if necessary
* Inspect the messages, and update `RE_INVALID` and `RE_DECISIONS`
* Inspect the output, and use `integer_formatter` on values if possible
* Inspect the data in `summaries`, and add an entry to `datasets:validate:values`
* Run `rake datasets:validate:values` and make corrections if necessary
* Add an entry to `identifiers.md`
* Inspect the data in `summaries`, and add `position` to the entry in `TEMPLATES` if possible
* Run `rake datasets:normalize` if `position` was added
* Add any jurisdiction-specific [scripts](#scripts) or [notes](#notes) to this readme

## Notes

This project does not publish all data elements published by jurisdictions, primarily because they are of low value, hard to normalize, or unique to a jurisdiction.

* Newfoundland and Labrador: comments, footnotes
* Calgary: exemptions
* Edmonton: status
* Burlington: exemptions, time to complete
* Greater Sudbury: status, time to complete, notice of extension, notice to affected party, exemptions, appeal number

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
* [Best Practice Guidance on Disclosure Logs](https://web.archive.org/web/20091211130521/http://www.foi.gov.uk/guidance/disclosure_logs.pdf)
* [Australia: Disclosure Log](https://www.oaic.gov.au/freedom-of-information/foi-guidelines/part-14-disclosure-log)

### Nomenclature

In terms of the prevalence of FOI versus ATI:

* 7 jurisdictions have a Freedom of Information and Protection of Privacy Act (AB, BC, MB, NS, ON, PE, SK)
* 4 Access to Information and Protection of Privacy Act (NL, NT, NU, YT)
* 1 Access to Information Act (Canada)
* 1 Right to Information and Protection of Privacy Act (NB)
* 1 An Act respecting Access to Documents Held by Public Bodies and the Protection of Personal Information (QC)

In other words, use whatever term you prefer.

Copyright (c) 2015 James McKinney, released under the MIT license
