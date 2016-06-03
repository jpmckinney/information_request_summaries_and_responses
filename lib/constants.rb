# The headers sometimes change.
CA_HEADERS = {
  'year' => 'year', # 2015 'Year / Année', 2014 'Year / Annee'
  'month' => 'month', # 2015 'Month / Mois (1-12)', 2014 'Month / Mois'
  'request_number' => 'identifier', # 'Request Number / Numero de la demande'
  'summary_en' => 'abstract_en', # 'English Summary / Sommaire de la demande en anglais'
  'summary_fr' => 'abstract_fr', # 'French Summary / Sommaire de la demande en français'
  'disposition' => 'decision', # 'Disposition'
  'pages' => 'number_of_pages', # 'Number of Pages / Nombre de pages'
  'owner_org' => 'organization_id', # 'Org id'
  'owner_org_title' => 'organization', # 'Org'
}

# #ca_disposition?
CA_DISPOSITIONS = Set.new(load_yaml('dispositions.yml')).freeze

# #normalize_decision
RE_PARENTHETICAL_CITATION = /\(.\)/.freeze
RE_PARENTHETICAL = /\([^)]+\)?/.freeze
# Empty string, cell reference, number, date, or exact string.
RE_INVALID = /\A(?:|=(?:f\d+)?|\d+|[a-z]{3} \d{1,2}|[\d ]{10}|closed|disposition|electronic package sent sept28 15|other|request is disregarded|request number|statement of disagreement filed|test disposition)\z/.freeze
RE_DECISIONS = {
  'correction' => /\bcorrection\b/,
  'discontinued' => /\b(?:abandon|consult other institution\b|forwarded out\b|transferred\b|withdrawn\b)/,
  'in progress' => /\bin (?:progress|treatment)\b/,
  'treated informally' => /\binformal/,
  # This order matters.
  'disclosed in part' => /\b(?:disclosed existing records except\b|part)/,
  'nothing disclosed' => /\A(?:disregarded|dublicate request|nhq release refused)\z|\Aex[ce]|\b(?:all? .*\b(?:ex[ce]|withheld\b)|aucun|available\b|den|inexistant\b|n existent pas\b|no(?:\b|n existent\b|ne\b|t)|public|unable to process\b)/,
  'all disclosed' => /\Adisclosed(?: (?:all|completely))?\z|\Adivulgation complète\z|\b(?:all (?:d|information\b)|enti|full|total)/,
}.freeze

APPLICANT_TYPES = {
  'academic/researcher' => 'academia',
  'researcher' => 'academia',

  'business by agent' => 'business',
  'business' => 'business',
  'business/commercial' => 'business',
  'law firm' => 'business',

  'other governments' => 'government',
  'other public body' => 'government',

  'media' => 'media',

  'association' => 'organization',
  'association/group' => 'organization',
  'interest group' => 'organization',
  'organization/interest group' => 'organization',
  'political party' => 'organization',

  'general public' => 'public',
  'individual by agent' => 'public',
  'individual' => 'public',
  'individual/public' => 'public',

  '"' => nil,
  'agent' => nil,
  'fire reports' => nil,
  'formal' => nil,
  'other' => nil,
  'sensitive' => nil,
}
CLASSIFICATIONS = {
  'consult' => 'consult',

  'general (continuing)' => 'general',
  'general information' => 'general',
  'general records' => 'general',

  'correction of personal information' => 'personal',
  'correction' => 'personal',
  'personal health information' => 'personal',
  'personal information' => 'personal',

  'personal health information/general informaiton' => 'mixed',
  'personal health information/general information' => 'mixed',
  'personal information/general information' => 'mixed',

  'investigation' => nil, # ca_ab_edmonton: review, privacy complaint
}

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
