# cron:upload and datasets:download
# @see https://docs.google.com/spreadsheets/d/1WQ6kWL5hAEThi31ZQtTZRX5E8_Y9BwDeEWATiuDakTM/edit#gid=0
DATASET_URLS = {
  # http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c
  'ca' => 'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
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
RE_INVALID = /\A(?:|=(?:f\d+)?|\d+|[a-z]{3} \d{1,2}|electronic package sent sept28 15|other|request number|statement of disagreement filed|test disposition)\z/.freeze
RE_DECISIONS = {
  'abandoned' => /\b(?:abandon|withdrawn\b)/,
  'correction' => /\bcorrection\b/,
  'in progress' => /\bin (?:progress|treatment)\b/,
  'treated informally' => /\binformal/,
  'transferred' => /\b(?:consult other institution|forwarded out|transferred)\b/,
  # This order matters.
  'disclosed in part' => /\b(?:disclosed existing records except\b|part)/,
  'nothing disclosed' => /\A(?:disregarded|dublicate request|nhq release refused)\z|\Aex[ce]|\b(?:all? .*\b(?:ex[ce]|withheld\b)|aucun|available\b|den|inexistant\b|no(?:\b|n existent\b|ne\b|t)|public|unable to process\b)/,
  'all disclosed' => /\Adisclosed\z|\b(?:all (?:d|information\b)|enti|full|total)/,
}.freeze

# #records_from_source
NON_CSV_SOURCES = Set.new([
  'ca_bc',
  'ca_ns_halifax',
]).freeze
CSV_ENCODINGS = {
  'ca_nl' => 'windows-1252:utf-8',
}.freeze
