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
