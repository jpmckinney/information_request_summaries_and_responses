require 'csv'
require 'open-uri'
require 'yaml'

require 'nokogiri'
require 'unicode_utils/downcase'

def assert(message)
  raise message unless yield
end


desc 'Prints Federal Identity Program names'
task :federal_identity_program do
  output = {}

  document = Nokogiri::HTML(open('http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/communications/fip-pcim/reg-eng.asp'))
  document.xpath('//table[1]/tbody/tr').reverse.each_with_index do |tr|
    legal_title = tr.xpath('./td[2]/text()').text.gsub(/\p{Space}+/, ' ').strip
    applied_title = tr.xpath('./td[4]/text()').text.gsub(/\p{Space}+/, ' ').strip
    unless applied_title.empty?
      output[legal_title] = applied_title
    end
  end

  puts YAML.dump(output)
end

desc 'Prints abbreviations'
task :abbreviations do
  output = {}

  CSV.foreach('atisummaries.csv', headers: true) do |row|
    id = row.fetch('Org id')
    value = row.fetch('Org').split(/ [|-] /)[0]
    if output.key?(id)
      assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
    else
      output[id] = value
    end
  end

  puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
end

desc 'Print emails'
task :emails do
  corrections = YAML.load(File.read('_data/federal_identity_program.yml')).merge({
    # Web => CSV
    'Civilian Review and Complaints Commission for the Royal Canadian Mounted Police' => 'Commission for Public Complaints Against the RCMP',
    'Federal Public Service Health Care Plan Administration Authority' => 'Public Service Health Care Plan',
    'National Defence and the Canadian Armed Forces' => 'National Defence',
    'Office of the Ombudsman National Defence and Canadian Forces' => 'National Defence and Canadian Forces Ombudsman',
  })

  def normalize(string)
    UnicodeUtils.downcase(string).strip.
      sub(/\Aport of (.+)/, '\1 port authority'). # word order
      sub(' commissionner ', ' commissioner '). # typo
      sub(' transaction ', ' transactions '). # typo
      sub('î', 'i'). # typo
      sub(/ \(.+\)/, ''). # parentheses
      sub(/\A(?:office of )?the /, ''). # prefixes
      gsub(/\band (?:employment )?/, ''). # infixes
      sub(/(?: agency| company| corporation| inc\.|, the)\z/, ''). # suffixes
      sub(/(?: of)? canada\z/, '') # suffixes
  end

  def parent(string)
    UnicodeUtils.downcase(string[/\((?:see)? *([^)]+)/, 1].to_s)
  end

  output = {
    # 1. Open http://open.canada.ca/en/search/ati
    # 2. Filter by the organization
    # 3. Click "Make an informal request for: ..."
    # 4. Get the email address from the URL
    'ahrc-pac' => 'amanda.wilson@hc-sc.gc.ca',
    'vfpa-apvf' => 'AccesstoInformation@portmetrovancouver.com',
  }
  errors = {}
  mapping = {}

  names = {}
  abbreviations = YAML.load(File.read('_data/abbreviations.yml'))
  abbreviations.each do |id,name|
    output[id] ||= nil # easier to see which are missing
    names[normalize(corrections.fetch(name, name))] = id
  end

  document = Nokogiri::HTML(open('http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/atip-aiprp/coord-eng.asp').read)
  document.xpath('//@href[starts-with(.,"mailto:")]').each do |href|
    name = href.xpath('../../strong').text.gsub(/\p{Space}+/, ' ').strip
    normalized = normalize(corrections.fetch(name, name))
    backup = normalize(parent(name))
    value = href.value.gsub(/\Amailto:/, '').downcase
    if names.key?(normalized) || names.key?(backup)
      id = names[normalized] || names[backup]
      if output[id]
        assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
      else
        output[id] = value
        mapping[name] = abbreviations[names[normalized] || names[backup]]
      end
    else
      errors[value] ||= []
      errors[value] << name
    end
  end

  $stderr.puts YAML.dump(errors)
  $stderr.puts errors.size

  mapping.reject!{|to,from| from == to}
  mapping.each do |to,from|
    $stderr.puts '%-60s %s' % [from, to]
  end
  $stderr.puts mapping.size

  puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
end
