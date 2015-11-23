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
    corrections = CORRECTIONS

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

    CSV.open(File.join('support', 'mismatches.csv'), 'w') do |csv|
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