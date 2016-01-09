# cron:upload and datasets:download
# @see https://docs.google.com/spreadsheets/d/1WQ6kWL5hAEThi31ZQtTZRX5E8_Y9BwDeEWATiuDakTM/edit#gid=0
DATASET_URLS = {
  # http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c
  'ca' => 'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
  # http://www.calgary.ca/CA/City-Clerks/Pages/Freedom-of-Information-and-Protection-of-Privacy/Freedom-of-Information-and-Protection-of-Privacy.aspx
  'ca_ab_calgary' => 'http://www.calgary.ca/CA/city-clerks/Documents/Freedom-of-Information-and-Protection-of-Privacy/Disclosure_Log_of_Closed_FOIP_Requests.xls',
  # https://data.edmonton.ca/City-Administration/FOIP-Requests/u2wt-gn9w
  'ca_ab_edmonton' => 'https://data.edmonton.ca/api/views/u2wt-gn9w/rows.csv?accessType=DOWNLOAD',
  # http://opendata.gov.nl.ca/public/opendata/page/?page-id=datasetdetails&id=222
  'ca_nl' => 'http://opendata.gov.nl.ca/public/opendata/filedownload/?file-id=4383',
  # http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0
  'ca_on_burlington' => 'http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0.csv',
  # http://opendata.greatersudbury.ca/datasets/5a7bb9da5c7d4284a9f7ea5f6e8e9364_0
  'ca_on_greater_sudbury' => 'http://opendata.greatersudbury.ca/datasets/5a7bb9da5c7d4284a9f7ea5f6e8e9364_0.csv',
}

# #ca_normalize and ca:emails:search_page
CA_CORRECTIONS = {
  # Web => CSV
  'Canada Science and Technology Museum' => 'Canada Science and Technology Museums Corporation',
  'Civilian Review and Complaints Commission for the RCMP' => 'Commission for Public Complaints Against the RCMP',
}.freeze

# #ca_disposition?
CA_DISPOSITIONS = Set.new(load_yaml('dispositions.yml')).freeze

# #normalize_decision
RE_PARENTHETICAL_CITATION = /\(.\)/.freeze
RE_PARENTHETICAL = /\([^)]+\)?/.freeze
# Empty string, number, date, or exact string.
RE_INVALID = /\A(?:|=(?:f\d+)?|\d+|[a-z]{3} \d{1,2}|electronic package sent sept28 15|other|request is disregarded|request number|statement of disagreement filed|test disposition)\z/.freeze
RE_DECISIONS = {
  'correction' => /\bcorrection\b/,
  'discontinued' => /\b(?:abandon|consult other institution\b|forwarded out\b|transferred\b|withdrawn\b)/,
  'in progress' => /\bin (?:progress|treatment)\b/,
  'treated informally' => /\binformal/,
  # This order matters.
  'disclosed in part' => /\b(?:disclosed existing records except\b|part)/,
  'nothing disclosed' => /\A(?:disregarded|dublicate request|nhq release refused)\z|\Aex[ce]|\b(?:all? .*\b(?:ex[ce]|withheld\b)|aucun|available\b|den|inexistant\b|no(?:\b|n existent\b|ne\b|t)|public|unable to process\b)/,
  'all disclosed' => /\Adisclosed(?: completely)?\z|\b(?:all (?:d|information\b)|enti|full|total)/,
}.freeze

# #records_from_source
NON_CSV_SOURCES = Set.new([
  'ca_bc',
  'ca_ns_halifax',
  'ca_on_markham',
  'ca_on_ottawa',
]).freeze
CSV_ENCODINGS = {
  'ca_nl' => 'windows-1252:utf-8',
}.freeze
