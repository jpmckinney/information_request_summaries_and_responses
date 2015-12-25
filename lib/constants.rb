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
RE_INVALID = /\A(?:|=(?:f\d+)?|\d+|[a-z]{3} \d{1,2}|consult other institution|electronic package sent sept28 15|other|request number|test disposition)\z/.freeze
RE_DECISIONS = {
  'abandoned' => /\b(?:abandon|withdrawn\b)/,
  'correction' => /\bcorrection\b/,
  'in progress' => /\bin (?:progress|treatment)\b/,
  'treated informally' => /\binformal/,
  'transferred' => /\btransferred\b/,
  # This order matters.
  'disclosed in part' => /\b(?:disclosed existing records except\b|part)/,
  'nothing disclosed' => /\A(?:disregarded|dublicate request|nhq release refused)\z|\Aex[ce]|\b(?:all? .*\b(?:ex[ce]|withheld\b)|aucun|available\b|den|no(?:\b|ne\b|t)|public|unable to process)/,
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
TEMPLATES = {
  'ca' => {
    'division_id' => 'ocd-division/country:ca',
    'identifier' => '/Request Number ~1 Numero de la demande',
    'date' => lambda{|data|
      year = Integer(JsonPointer.new(data, '/Year ~1 Année').value)
      month = Integer(JsonPointer.new(data, '/Month ~1 Mois (1-12)').value)
      ['date', Date.new(year, month, 1).strftime('%Y-%m')]
    },
    'abstract' => lambda{|data|
      en = JsonPointer.new(data, '/English Summary ~1 Sommaire de la demande en anglais').value
      fr = JsonPointer.new(data, '/French Summary ~1 Sommaire de la demande en français').value
      ['abstract', en || fr]
    },
    'decision' => '/Disposition',
    'organization' => '/Org',
    'number_of_pages' => lambda{|data|
      v = JsonPointer.new(data, '/Number of Pages ~1 Nombre de pages').value
      ['number_of_pages', v && Integer(v)]
    },
  },
  'ca_bc' => {
    'division_id' => '/division_id',
    'id' => '/id',
    'identifier' => '/identifier',
    'date' => '/date',
    'abstract' => '/abstract',
    'organization' => '/organization',
    'number_of_pages' => '/number_of_pages',
    'url' => lambda{|data|
      v = JsonPointer.new(data, '/url').value
      ['url', URI.escape(v)]
    },
  },
  'ca_nl' => {
    'division_id' => 'ocd-division/country:ca/province:nl',
    'identifier' => '/Request Number',
    'date' => lambda{|data|
      year = JsonPointer.new(data, '/Year').value
      month = JsonPointer.new(data, '/Month').value
      year_month = JsonPointer.new(data, '/Month Name').value
      if month
        ['date', "#{year}-#{month.sub(/\A(?=\d\z)/, '0')}"]
      else
        ['date', Date.strptime(year_month, '%y-%b').strftime('%Y-%m')]
      end
    },
    'abstract' => '/Summary of Request',
    'decision' => '/Outcome of Request',
    'organization' => '/Department',
    'number_of_pages' => lambda{|data|
      v = JsonPointer.new(data, '/Number of Pages').value
      ['number_of_pages', v == 'EXCEL' ? nil : Integer(v)]
    },
  },
  'ca_ns_halifax' => {
    'division_id' => '/division_id',
    'identifier' => '/identifier',
    'date' => '/date',
    'abstract' => '/abstract',
    'decision' => '/decision',
    'number_of_pages' => '/number_of_pages',
  },
  'ca_on_burlington' => {
    'division_id' => 'ocd-division/country:ca/csd:3524002',
    'identifier' => lambda{|data|
      v = JsonPointer.new(data, '/No.').value
      ['identifier', v && Integer(v)]
    },
    'date' => '/Year',
    'decision' => '/Decision',
    'organization' => '/Dept Contact',
    'classification' => lambda{|data|
      v = JsonPointer.new(data, '/Request Type').value
      case v
      when 'General Records'
        ['classification', 'general']
      when 'Personal Information'
        ['classification', 'personal']
      else
        raise "unrecognized classification: #{v}" if v
      end
    },
  },
  'ca_on_greater_sudbury' => {
    'id' => '/FILE_NUMBER',
    'division_id' => 'ocd-division/country:ca/csd:3553005',
    'identifier' => lambda{|data|
      v = JsonPointer.new(data, '/FILE_NUMBER').value
      ['identifier', Integer(v.strip.match(/\AFOI ?\d{4}-(\d{1,4})\z/)[1])]
    },
    'date' => lambda{|data|
      v = JsonPointer.new(data, '/NOTICE_OF_DECISION_SENT').value
      ['date', v && (Date.strptime(v, '%m/%d/%Y') rescue Date.strptime(v, '%d/%m/%Y')).strftime('%Y-%m-%d')]
    },
    'abstract' => '/PUBLIC_DESCRIPTION',
    'decision' => lambda{|data|
      v = [
        '1_ALL_INFORMATION_DISCLOSED',
        '2_INFORMATION_DISCLOSED_IN_PART',
        '3_NO_INFORMATION_DISCLOSED',
        '4_NO_RESPONSIVE_RECORD_EXIST',
        '5_REQUEST_WITHDRAWN,_ABANDONED_OR_NON-JURISDICTIONAL',
      ].select do |header|
        JsonPointer.new(data, "/#{header}").value
      end
      assert("expected a single decision: #{v}"){v.size < 2}
      ['decision', v[0]]
    },
    'organization' => '/DEPARTMENT',
    'classification' => lambda{|data|
      v = JsonPointer.new(data, '/PERSONAL_OR_GENERAL').value
      ['classification', v.downcase.strip]
    },
  },
  'ca_on_toronto' => {
    'division_id' => 'ocd-division/country:ca/csd:3520005',
    'identifier' => '/Request_Number',
    'date' => lambda{|data|
      v = JsonPointer.new(data, '/Decision_Communicated').value
      ['date', v && (Date.strptime(v, '%d-%m-%Y') rescue Date.strptime(v, '%Y-%m-%d')).strftime('%Y-%m-%d')]
    },
    'abstract' => '/Summary',
    'decision' => '/Name',
    'number_of_pages' => lambda{|data|
      v = JsonPointer.new(data, '/Number_of_Pages_Released').value
      ['number_of_pages', v && Integer(v.sub(/\.0\z/, ''))]
    },
    'classification' => lambda{|data|
      v = JsonPointer.new(data, '/Request_Type').value
      case v
      when 'General Records'
        ['classification', 'general']
      when 'Personal Information', 'Personal Health Information', 'Correction of Personal Information'
        ['classification', 'personal']
      else
        raise "unrecognized classification: #{v}"
      end
    },
  },
}.freeze
