# Information Request Summaries and Responses

All government bodies in Canada are subject to some freedom of information statute. Some bodies publish summaries of completed information requests. Fewer publish responses to completed information requests. This repository contains scripts for aggregating what is available.

## Scripts

### Canada

Get the alternate names of organizations to make corrections:

    rake federal_identity_program > support/federal_identity_program.yml

Get the abbreviations of organizations to match across datasets:

    rake abbreviations > support/abbreviations.yml

Get organizations' emails from the coordinators page:

    rake emails:coordinators_page > support/emails_coordinators_page.yml

Get organizations' emails from the search page:

    rake emails:search_page > support/emails_search_page.yml

Compare organizations' emails from different sources:

    rake emails:compare

Construct the URL of the web form of each summary:

    rake urls:get > support/urls.yml

Compare the constructed URLs to the search page's URLs:

    rake urls:validate

Build a histogram of number of summaries per organization:

    rake histogram

Search for datasets across multiple catalogs with Namara.io:

    query="access to information" rake datasets:search

Download summaries from catalogs:

    rake datasets:download

### British Columbia

Download the metadata for responses from BC:

    ruby bc_scraper.rb

Download the attachments for responses from BC:

    ruby bc_scraper.rb -a download

## Reference

<dl>
<dt><a href="/data/statutes.csv">statutes.csv</a></dt>
<dd>The names and URLs of all current freedom of information statutes in Canada.</dd>
<dt><a href="/data/keywords.csv">keywords.csv</a></dt>
<dd>The keywords used to refer to freedom of information in Canada.</dd>
</dl>

### Resources

* [Centre for Law and Democracy's Canadan RTI Rating](http://www.law-democracy.org/live/global-rti-rating/canadian-rti-rating/) (federal, provincial, territorial)
* [Newspapers Canada's FOI Audit](http://www.newspaperscanada.ca/FOI) (federal, provincial, territorial, municipal)
* [Global Right to Information Rating](http://www.rti-rating.org/) (federal)

## Nomenclature

In terms of the prevalence of FOI versus ATI:

* 7 jurisdictions have a Freedom of Information and Protection of Privacy Act (AB, BC, MB, NS, ON, PE, SK)
* 4 Access to Information and Protection of Privacy Act (NL, NT, NU, YT)
* 1 Access to Information Act (Canada)
* 1 Right to Information and Protection of Privacy Act (NB)
* 1 An Act respecting Access to Documents Held by Public Bodies and the Protection of Personal Information (QC)

In other words, use whatever term you prefer.

Copyright (c) 2015 James McKinney, released under the MIT license
