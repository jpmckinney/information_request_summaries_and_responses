# Assume a 1900 epoch.
# @see https://support.microsoft.com/en-us/kb/180162
EPOCH_1900 = Date.new(1900, 1, 1)

BC_DOCUMENT_TYPES = {
  'letters' => 'letter',
  'notes' => 'note',
  'files' => 'disclosure',
}.freeze

def date_formatter(property, path, patterns)
  return lambda{|data|
    v = JsonPointer.new(data, path).value
    # ca_on_toronto: the 2011-Q4 file has serial numbers.
    if v.nil? || v.strip.empty?
      [property, nil]
    elsif v[/\A\d+\.0\z/]
      [property, (EPOCH_1900 + Integer(v.sub(/\.0\z/, ''))).strftime('%Y-%m-%d')]
    else
      pattern = patterns.find do |pattern|
        Date.strptime(v, pattern) rescue false
      end
      if pattern.nil?
        puts "expected #{v.inspect} to match one of #{patterns}"
      end
      [property, Date.strptime(v, pattern).strftime('%Y-%m-%d')]
    end
  }
end

def decimal_formatter(property, path)
  return lambda{|data|
    v = JsonPointer.new(data, path).value
    # ca_on_greater_sudbury: value may be " $-   ".
    [property, v == ' $-   ' ? nil : v && '%.2f' % Float(v.strip.sub(/\A\$/, ''))]
  }
end

def integer_formatter(property, path)
  return lambda{|data|
    v = JsonPointer.new(data, path).value
    # ca_nl: number_of_pages is "EXCEL" if an Excel file is disclosed.
    # ca_on_toronto: number_of_pages has a decimal.
    [property, Integer === v ? v : v == 'EXCEL' ? nil : v && Integer(v.sub(/\.0\z/, ''))]
  }
end

def mapping_formatter(property, path, map = {})
  return lambda{|data|
    v = JsonPointer.new(data, path).value
    [property, v && map.fetch(v.downcase.strip, v.downcase.strip)]
  }
end

# The order of the keys should be the same as in the schema.
TEMPLATES = {
  'ca' => {
    'division_id' => 'ocd-division/country:ca',
    'identifier' => '/Request Number ~1 Numero de la demande',
    'organization' => '/Org',
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
    'number_of_pages' => integer_formatter('number_of_pages', '/Number of Pages ~1 Nombre de pages'),
  },
  'ca_bc' => {
    'division_id' => '/division_id',
    'identifier' => '/identifier',
    'alternate_identifier' => '/id',
    'position' => '/position',
    'abstract' => '/abstract',
    'organization' => '/organization',
    'applicant_type' => mapping_formatter('applicant_type', '/applicant_type', {
      'business' => 'business',
      'individual' => 'public',
      'interest group' => 'organization',
      'law firm' => 'business',
      'media' => 'media',
      'other governments' => 'government',
      'other public body' => 'government',
      'political party' => 'organization',
      'researcher' => 'academia',
    }),
    'processing_fee' => '/processing_fee',
    'date' => '/date',
    'url' => lambda{|data|
      v = JsonPointer.new(data, '/url').value
      ['url', URI.escape(v)]
    },
    'byte_size' => '/byte_size',
    'number_of_pages' => '/number_of_pages',
    'number_of_rows' => '/number_of_rows',
    'duration' => '/duration',
    'documents' => lambda{|data|
      documents = []
      ['letters', 'notes', 'files'].each do |property|
        if data[property]
          data[property].each do |file|
            documents << {
              'type' => BC_DOCUMENT_TYPES.fetch(property),
              'download_url' => URI.escape(file.delete('url')),
            }.merge(file.slice('media_type', 'byte_size', 'number_of_pages', 'number_of_rows', 'duration'))
          end
        end
      end
      ['documents', documents]
    },
  },
  'ca_nl' => {
    'division_id' => 'ocd-division/country:ca/province:nl',
    'identifier' => lambda{|data|
      v = JsonPointer.new(data, '/Request Number').value
      ['identifier', v.strip]
    },
    'position' => lambda{|data|
      v = JsonPointer.new(data, '/Request Number').value
      ['position', Integer(v.strip.match(%r{\A[A-Z]{2,5}/(\d{1,2})/\d{4}\z})[1])]
    },
    'abstract' => '/Summary of Request',
    'organization' => '/Department',
    'application_fee' => decimal_formatter('application_fee', '/$5 Application Fees Paid'),
    'processing_fee' => decimal_formatter('processing_fee', '/Processing Fees Paid'),
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
    'decision' => '/Outcome of Request',
    'number_of_pages' => integer_formatter('number_of_pages', '/Number of Pages'),
  },
  'ca_ns_halifax' => {
    'division_id' => '/division_id',
    'identifier' => '/identifier',
    'position' => '/position',
    'abstract' => '/abstract',
    'date' => '/date',
    'decision' => '/decision',
    'number_of_pages' => '/number_of_pages',
  },
  'ca_on_burlington' => {
    'division_id' => 'ocd-division/country:ca/csd:3524002',
    'position' => integer_formatter('position', '/No.'),
    'organization' => '/Dept Contact',
    'classification' => mapping_formatter('classification', '/Request Type', {
      'general records' => 'general',
      'personal information' => 'personal',
    }),
    'applicant_type' => mapping_formatter('applicant_type', '/Source', {
      'association/group' => 'organization',
      'business' => 'business',
      'individual/public' => 'public',
      'media' => 'media',
    }),
    'date' => '/Year',
    'decision' => '/Decision',
  },
  'ca_on_greater_sudbury' => {
    'division_id' => 'ocd-division/country:ca/csd:3553005',
    'identifier' => lambda{|data|
      v = JsonPointer.new(data, '/FILE_NUMBER').value
      ['identifier', v.gsub(' ', '')]
    },
    'position' => lambda{|data|
      v = JsonPointer.new(data, '/FILE_NUMBER').value
      ['position', Integer(v.gsub(' ', '').match(/\AFOI\d{4}-(\d{1,3})\z/)[1])]
    },
    'abstract' => '/PUBLIC_DESCRIPTION',
    'organization' => '/DEPARTMENT',
    'classification' => mapping_formatter('classification', '/PERSONAL_OR_GENERAL'),
    'applicant_type' => mapping_formatter('applicant_type', '/SOURCE_OF_REQUESTS', {
      'agent' => nil,
      'business' => 'business',
      'government' => 'government',
      'individual' => 'public',
      'individual by agent' => 'public',
      'media' => 'media',
    }),
    'date_accepted' => date_formatter('date_accepted', '/DATE_RECEIVED', ['%m/%d/%Y']),
    'application_fee' => decimal_formatter('application_fee', '/APPLICATION_FEES_COLLECTED'),
    'processing_fee' => decimal_formatter('processing_fee', '/ADDITION_FEES_COLLECTED'),
    'waived_fees' => decimal_formatter('waived_fees', "/TOTAL_AMOUNT\n_OF_FEES_WAIVED"),
    'unpaid_fees' => decimal_formatter('unpaid_fees', '/ FEES_AMOUNT_NOT_PAID '),
    'date' => date_formatter('date', '/NOTICE_OF_DECISION_SENT', ['%m/%d/%Y', '%d/%m/%Y']),
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
      if v.size > 1
        puts "expected a single decision: #{v}"
      end
      ['decision', v[-1]]
    },
  },
  'ca_on_toronto' => {
    'division_id' => 'ocd-division/country:ca/csd:3520005',
    'identifier' => '/Request_Number',
    'position' => lambda{|data|
      v = JsonPointer.new(data, '/Request_Number').value
      ['position', v.strip.empty? ? nil : Integer(v.match(/\A(?:AG|AP|COR|PHI)-\d{4}-0*(\d+)\z/)[1])]
    },
    'abstract' => '/Summary',
    'classification' => mapping_formatter('classification', '/Request_Type', {
      'general records' => 'general',
      'personal information' => 'personal',
      'personal health information' => 'personal',
      'correction of personal information' => 'personal',
    }),
    'applicant_type' => mapping_formatter('applicant_type', '/Source', {
      'academic/researcher' => 'academia',
      'association' => 'organization',
      'business' => 'business',
      'fire reports' => nil,
      'formal' => nil,
      'government' => 'government',
      'individual by agent' => 'public',
      'media' => 'media',
      'other' => nil,
      'public' => 'public',
      'researcher' => 'academia',
      'sensitive' => nil,
    }),
    'date_accepted' => date_formatter('date_accepted', '/Date_Complete_Received', ['%Y-%m-%d']),
    'date' => date_formatter('date', '/Decision_Communicated', ['%d-%m-%Y', '%Y-%m-%d']),
    'decision' => '/Name',
    'number_of_pages' => integer_formatter('number_of_pages', '/Number_of_Pages_Released'),
  },
}.freeze