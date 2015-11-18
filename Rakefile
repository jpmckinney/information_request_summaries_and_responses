require 'csv'
require 'open-uri'
require 'safe_yaml'

require 'nokogiri'
require 'pupa'
require 'unicode_utils/downcase'

SafeYAML::OPTIONS[:default_mode] = :safe

def assert(message)
  raise message unless yield
end

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: '_cache', expires_in: 604800, level: 'WARN') # 1 week
end

def load_yaml(basename)
  YAML.load(File.read(File.join('_data', basename)))
end

desc 'Prints Federal Identity Program names'
task :federal_identity_program do
  output = {}

  url = 'http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/communications/fip-pcim/reg-eng.asp'
  client.get(url).body.xpath('//table[1]/tbody/tr').reverse.each_with_index do |tr|
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

  urls = [
    'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
    'http://open.canada.ca/vl/dataset/ati/resource/91a195c7-6985-4185-a357-b067b347333c/download/atinone.csv',
  ]
  urls.each do |url|
    CSV.parse(client.get(url).body, headers: true) do |row|
      id = row.fetch('Org id')
      value = row.fetch('Org').split(/ [|-] /)[0]
      if output.key?(id)
        assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
      else
        output[id] = value
      end
    end
  end

  puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
end

namespace :emails do
  def normalize_email(string)
    string.gsub(/mailto:/, '').downcase
  end

  desc 'Print emails from the coordinators page'
  task :coordinators_page do
    def normalize_name(string)
      UnicodeUtils.downcase(string).strip.
        sub(/\Aport of (.+)/, '\1 port authority'). # word order
        sub(' commissionner ', ' commissioner '). # typo
        sub(' transaction ', ' transactions '). # typo
        sub('î', 'i'). # typo
        sub(/ \(.+/, ''). # parentheses
        sub(/\A(?:canadian|(?:office of )?the) /, ''). # prefixes
        gsub(/\band (?:employment )?/, ''). # infixes
        sub(/, ltd\.\z/, ''). # suffixes
        sub(/(?: agency| company| corporation| inc\.|, the)\z/, ''). # suffixes
        sub(/(?: of)? canada\z/, '') # suffixes
    end

    def parent(string)
      UnicodeUtils.downcase(string[/\((?:see)? *([^)]+)/, 1].to_s)
    end

    corrections = load_yaml('federal_identity_program.yml').merge({
      # Web => CSV
      'Civilian Review and Complaints Commission for the Royal Canadian Mounted Police' => 'Commission for Public Complaints Against the RCMP',
      'Federal Public Service Health Care Plan Administration Authority' => 'Public Service Health Care Plan',
      'National Defence and the Canadian Armed Forces' => 'National Defence',
      'Office of the Ombudsman National Defence and Canadian Forces' => 'National Defence and Canadian Forces Ombudsman',
    })

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

    abbreviations = load_yaml('abbreviations.yml')
    names = {}

    abbreviations.each do |id,name|
      output[id] ||= nil # easier to see which are missing
      names[normalize_name(corrections.fetch(name, name))] = id
    end

    url = 'http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/atip-aiprp/coord-eng.asp'
    client.get(url).body.xpath('//@href[starts-with(.,"mailto:")]').each do |href|
      name = href.xpath('../../strong').text.gsub(/\p{Space}+/, ' ').strip
      normalized = normalize_name(corrections.fetch(name, name))
      backup = normalize_name(parent(name))
      value = normalize_email(href.value)
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

  desc 'Print emails from the search page'
  task :search_page do
    corrections = {
      # Web => CSV
      'Canada Science and Technology Museum' => 'Canada Science and Technology Museums Corporation',
      'Civilian Review and Complaints Commission for the RCMP' => 'Commission for Public Complaints Against the RCMP',
    }

    output = {}
    xpath = '//a[@title="Contact this organization about this ATI Request."]/@href'

    abbreviations = load_yaml('abbreviations.yml')
    names = abbreviations.invert

    abbreviations.each do |id,name|
      output[id] ||= nil # easier to see which are missing
    end

    url = 'http://open.canada.ca/en/search/ati'
    client.get(url).body.xpath('//ul[@id="facetapi-facet-apachesolrsolr-0-block-ss-ati-organization-en"]//a').each do |a|
      url = "http://open.canada.ca#{a[:href]}"
      document = client.get(url).body
      href = document.at_xpath(xpath)

      unless href
        link = document.at_xpath('//li[@class="next"]//@href')
        if link
          href = client.get("http://open.canada.ca#{link.value}").body.at_xpath(xpath)
        end
      end

      if href
        name = a.xpath('./text()').text.strip
        id = names.fetch(corrections.fetch(name, name))
        value = normalize_email(href.value.match(/email=([^&]+)/)[1])
        if output[id]
          assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
        else
          output[id] = value
        end
      else
        $stderr.puts "expected #{a.xpath('./span[@class="badge"]').text} summaries at #{url}"
      end
    end

    puts YAML.dump(output)
  end

  desc 'Compares emails from different sources'
  task :compare do
    abbreviations = load_yaml('abbreviations.yml')
    coordinators_page = load_yaml('emails_coordinators_page.yml')
    search_page = load_yaml('emails_search_page.yml')

    CSV.open(File.join('_data', 'mismatches.csv'), 'w') do |csv|
      csv << ['Org id', 'Org', 'Coordinators page', 'Search page']
      coordinators_page.each do |id,email_coordinators_page|
        name = abbreviations.fetch(id)
        email_search_page = search_page.fetch(id)
        unless email_search_page.nil? || email_coordinators_page == email_search_page
          csv << [id, name, email_coordinators_page, email_search_page]
        end
      end
    end
  end
end

desc 'Prints URLs to forms'
task :urls do
  corrections = {
    # Web => CSV
    'Canada Science and Technology Museums Corporation' => 'Canada Science and Technology Museum',
    'Commission for Public Complaints Against the RCMP' => 'Civilian Review and Complaints Commission for the RCMP',
  }

  output = {}

  dispositions = load_yaml('dispositions.yml')
  re = "(?:#{dispositions.join('|')})"
  emails = load_yaml('emails_search_page.yml')

  row_number = 1
  url = 'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv'
  CSV.parse(client.get(url).body.force_encoding('utf-8'), headers: true) do |row|
    row_number += 1

    # The informal request URLs don't make this correction.
    if row['French Summary / Sommaire de la demande en français'] && row['French Summary / Sommaire de la demande en français'][/\A#{re}/i]
      row['French Summary / Sommaire de la demande en français'], row['Disposition'] = row['Disposition'], row['French Summary / Sommaire de la demande en français']
    end

    assert("#{row_number}: expected '/' in Disposition: #{row['Disposition']}"){
      row['Disposition'].nil? || row['Disposition'][/\A#{re}\z/i] || row['Disposition'][%r{ ?/ ?}]
    }
    assert("#{row_number}: expected '|' or '-' in Org: #{row['Org']}"){
      row['Org'][/ [|-] /]
    }

    organization = row.fetch('Org').split(/ [|-] /)[0]
    organization = corrections.fetch(organization, organization)
    number = row.fetch('Request Number / Numero de la demande')
    pages = Integer(row['Number of Pages / Nombre de pages'])

    params = {
      org: organization,
      req_num: number,
      disp: row.fetch('Disposition').to_s.split(%r{ / })[0],
      year: Integer(row.fetch('Year / Année')),
      month: Date.new(2000, Integer(row.fetch('Month / Mois (1-12)')), 1).strftime('%B'),
      pages: pages,
      req_sum: row.fetch('English Summary / Sommaire de la demande en anglais'),
      req_pages: pages,
      email: emails.fetch(row.fetch('Org id')),
    }

    # The government has very creative URL escaping.
    query = params.map do |key,value|
      value = value.to_s.
        gsub(/\r\n?/, "\n").
        gsub("\a", '') # alarm

      if [:disp, :email, :org, :req_num].include?(key)
        "#{CGI.escape(key.to_s)}=#{value}"
      else
        value = CGI.escapeHTML(value).
          gsub('&#39;', '&#039;')
        "#{CGI.escape(key.to_s)}=#{CGI.escape(value)}".
          gsub('+', '%20').
          gsub('%2F', '/').
          gsub('%7E', '~')
      end
    end * '&'

    output["#{organization}-#{number.to_s.gsub(/\r\n?/, "\n")}"] = "/forms/contact-ati-org?#{query}"
  end

  puts YAML.dump(output)
end
