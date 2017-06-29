namespace :ca do
  # ca:emails:coordinators_page ca:emails:search_page
  def ca_normalize_email(string)
    string.gsub(/mailto:/, '').downcase
  end

  # #ca_normalize
  def ca_disposition?(text)
    CA_DISPOSITIONS.include?(text.downcase.
      gsub(RE_PARENTHETICAL, '').
      gsub(/[\p{Punct}￼]/, ' '). # special character
      gsub(/\p{Space}+/, ' ').strip)
  end

  def ca_normalize(data)
    rows = []

    row_number = 1
    CSV.parse(data, headers: true, header_converters: ->(h) { CA_HEADERS.fetch(h, h) }) do |row|
      row_number += 1

      # The informal request URLs don't make this correction.
      if row['abstract_fr'] && ca_disposition?(row['abstract_fr'].split(' / ', 2)[0])
        row['abstract_fr'], row['decision'] = row['decision'], row['abstract_fr']
      end
      if row['decision'] && row['decision'][/\A\d+\z/] && row['number_of_pages'] == '0'
        row['number_of_pages'], row['decision'] = row['decision'], nil
      end

      assert("#{row_number}: expected '/' or '|' in decision: #{row['decision'].inspect}"){
        row['decision'].nil? || row['decision'][%r{[/|]}] || ca_disposition?(row['decision']) || normalize_decision(row['decision']).nil?
      }
      assert("#{row_number}: expected '|' or '-' in organization: #{row['organization']}"){
        row['organization'][/ [|-] /]
      }

      record = {
        'year' => Integer(row.fetch('year')),
        'month' => Integer(row.fetch('month')),
      }

      if row.size > 4
        record.merge!({
          'identifier' => row.fetch('identifier'),
          'abstract_en' => row.fetch('abstract_en'),
          'abstract_fr' => row.fetch('abstract_fr'),
          'decision' => row.fetch('decision').to_s.split(%r{ / })[0],
          'number_of_pages' => Integer(row['number_of_pages']),
        })
      end

      record.merge!({
        'organization_id' => row.fetch('organization_id'),
        'organization' => row.fetch('organization').split(/ [|-] /)[0],
      })

      rows << record
    end

    rows
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

  desc 'Prints organization abbreviations'
  task :abbreviations do
    output = {}

    urls = [
      'http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c/resource/19383ca2-b01a-487d-88f7-e1ffbc7d39c2/download/ati.csv',
      'http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c/resource/5a1386a5-ba69-4725-8338-2f26004d7382/download/ati-nil.csv',
    ]
    urls.each do |url|
      ca_normalize(client.get(url).body.force_encoding('utf-8')).each do |row|
        id = row.fetch('organization_id')
        value = row.fetch('organization').split(/ [|-] /)[0].strip
        if output.key?(id)
          assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
        else
          output[id] = value
        end
      end
    end

    puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
  end

  desc 'Prints histogram data'
  task :histogram do
    counts = Hash.new(0)

    url = 'http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c/resource/19383ca2-b01a-487d-88f7-e1ffbc7d39c2/download/ati.csv'
    ca_normalize(client.get(url).body.force_encoding('utf-8')).each do |row|
      if Integer(row['number_of_pages']).nonzero?
        counts[row.fetch('organization_id')] += 1
      end
    end

    puts <<-END
# install.packages("ggplot2")
library(ggplot2)
dat <- data.frame(id = c(#{counts.keys.map{|k| %("#{k}")}.join(', ')}), count = c(#{counts.values.map(&:to_s).join(', ')}))
# head(dat)
ggplot(dat, aes(x=count)) + geom_histogram(binwidth=50) + scale_y_sqrt()
END

    total = counts.size.to_f
    values = counts.values
    minimum = 0
    [10, 25, 50, 100, 250, 500, 1_000, 1_000_000].each do |maximum,message|
      count = values.count{|value| value > minimum && value <= maximum}
      puts '%d (%d%%) %d-%d' % [count, (count / total * 100).round, minimum + 1, maximum]
      minimum = maximum
    end
    puts total.to_i
  end

  namespace :emails do
    desc 'Print emails from the coordinators page'
    task :coordinators_page do
      def normalize(string)
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
        # If the contact point is the different for the child and the parent.
        if string['Indian Residential Schools Resolution Canada']
          ''
        # If the contact point is the same for the child and the parent.
        else
          { 'Canada Employment Insurance Commission' => 'Employment and Social Development Canada',
            'Canadian International Development Agency (see Global Affairs Canada )' => 'Foreign Affairs, Trade and Development Canada',
            'National Round Table on the Environment and the Economy (see Environment and Climate Change Canada)' => 'Environment Canada',
            'International Centre for Human Rights and Democratic Development (see Global Affairs Canada )' => 'Foreign Affairs, Trade and Development Canada',
            'Passport Canada (see Immigration, Refugees and Citizenship Canada)' => 'Citizenship and Immigration Canada',
          }.fetch(string, string[/\((?:formerly|[Ss]ee)? *([^)]+)/, 1].to_s)
        end
      end

      corrections = load_yaml('federal_identity_program.yml').merge({
        # Web => CSV
        'Canada Science and Technology Museums Corporation' => 'Canada Science and Technology Museum',
        'Civilian Review and Complaints Commission for the Royal Canadian Mounted Police' => 'Civilian Review and Complaints Commission for the RCMP',
        'Federal Public Service Health Care Plan Administration Authority' => 'Public Service Health Care Plan',
        'Global Affairs Canada (formely Foreign Affairs, Trade and Development Canada)' => 'Foreign Affairs, Trade and Development Canada',
        'National Defence and the Canadian Armed Forces' => 'National Defence',
        'Office of the Administrator of the Ship-source Oil Pollution Fund' => 'Ship-source Oil Pollution Fund',
        'Office of the Ombudsman National Defence and Canadian Forces' => 'National Defence and Canadian Forces Ombudsman',
        'Port Metro Vancouver' => 'Vancouver Fraser Port Authority',
      })

      output = {}
      # The names of organizations in `abbreviations.yml` to match against.
      names = {}
      # Organizations from the coordinators page match no organizations in `abbreviations.yml`.
      unmatched = {}
      # A list of organizations that are expected to have no match in `abbreviations.yml`.
      missing = {}
      # A list of non-exact organization name matches.
      mapping = {}

      abbreviations = load_yaml('abbreviations.yml')
      abbreviations.each do |id,name|
        output[id] ||= nil # easier to see which are missing
        names[normalize(corrections.fetch(name, name))] = id
      end

      CSV.foreach(File.join('support', 'missing.csv'), headers: true) do |row|
        missing[row['email']] = row
      end

      url = 'http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/atip-aiprp/coord-eng.asp'
      client.get(url).body.xpath('//@href[starts-with(.,"mailto:")]').each do |href|
        name = href.xpath('../../strong').text.gsub(/\p{Space}+/, ' ').strip
        normalized = normalize(corrections.fetch(name, name))
        backup = normalize(parent(name))
        email = ca_normalize_email(href.value)

        if names.key?(normalized) || names.key?(backup)
          id = names[normalized] || names[backup]
          if output[id]
            assert("#{output[id]} expected for #{id}, got\n#{email}"){output[id] == email}
          else
            output[id] = email
            mapping[name] = abbreviations[names[normalized] || names[backup]]
          end
        else
          unmatched[email] ||= []
          unmatched[email] << name
        end
      end

      # Only report new unmatched organizations.
      unmatched.reject! do |email,names|
        if missing.key?(email)
          row = missing.delete(email)
          assert("#{names} expected to include #{row['name']}"){names.map{|name| name.sub(/ \(.+/, '')}.include?(row['name'])}
          true
        end
      end

      # Report any rows to delete from `missing.csv`.
      if missing.any?
        $stderr.puts "Delete these rows from missing.csv:"
        $stderr.puts missing.values
        $stderr.puts missing.size
      end

      # Report any organizations from the coordinators page match no organizations in `abbreviations.yml`.
      if unmatched.any?
        $stderr.puts "If abbreviations.yml matches, add to `corrections`. If the contact point is shared, add to `parent`:"
        $stderr.puts YAML.dump(unmatched)
        $stderr.puts unmatched.size
      end

      # Report non-exact organization name matches for review.
      mapping.reject!{|from,to| from == to}
      if mapping.any?
        $stderr.puts 'Name matches (for review):'
        mapping.each do |from,to|
          $stderr.puts '%-125s %s' % [from, to]
        end
        $stderr.puts mapping.size
      end

      puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
    end

    desc 'Print emails from the search page'
    task :search_page do
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
          id = names.fetch(name)
          value = ca_normalize_email(href.value.match(/email=([^&]+)/)[1])
          if output[id]
            assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
          else
            output[id] = value
          end
        else
          $stderr.puts "expected an email from #{a.xpath('./span[@class="badge"]').text} summaries at #{url}"
        end
      end

      puts YAML.dump(output)
    end

    desc 'Compares emails from different sources'
    task :compare do
      abbreviations = load_yaml('abbreviations.yml')
      coordinators_page = load_yaml('emails_coordinators_page.yml')
      search_page = load_yaml('emails_search_page.yml')

      puts CSV.generate_line(['organization_id', 'organization', 'coordinators_page_email', 'search_page_email'])
      coordinators_page.each do |id,email_coordinators_page|
        name = abbreviations.fetch(id)
        email_search_page = search_page.fetch(id)
        unless email_search_page.nil? || email_coordinators_page == email_search_page
          puts CSV.generate_line([id, name, email_coordinators_page, email_search_page])
        end
      end
    end
  end

  namespace :urls do
    desc 'Prints URLs to forms'
    task :get do
      output = {}

      emails = load_yaml('emails_search_page.yml')

      url = 'http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c/resource/19383ca2-b01a-487d-88f7-e1ffbc7d39c2/download/ati.csv'
      ca_normalize(client.get(url).body.force_encoding('utf-8')).each do |row|
        organization = row.fetch('organization')
        number = row['identifier']
        pages = row.fetch('number_of_pages')

        params = {
          org: organization,
          req_num: number,
          disp: row.fetch('decision'),
          year: row.fetch('year'),
          month: Date.new(2000, row.fetch('month'), 1).strftime('%B'),
          pages: pages,
          req_sum: row.fetch('abstract_en'),
          req_pages: pages,
          email: emails.fetch(row.fetch('organization_id')),
        }

        query = params.map do |key,value|
          value = value.to_s.
            gsub(/\r\n?/, "\n").
            gsub("\a", '') # alarm

          if [:disp, :email, :org, :req_num].include?(key)
            # The government should escape these values.
            "#{ERB::Util.u(key.to_s)}=#{value}"
          else
            # Escapes HTML for inclusion in hidden input tags.
            value = ERB::Util.h(value).
              gsub('&#39;', '&#039;')

            # "/" and "~" are allowed in `query`.
            # @see http://tools.ietf.org/html/rfc3986#appendix-A
            "#{ERB::Util.u(key.to_s)}=#{ERB::Util.u(value)}".
              gsub('%2F', '/').
              gsub('%7E', '~')
          end
        end * '&'

        output["#{organization}-#{number.to_s.gsub(/\r\n?/, "\n")}"] = "/forms/contact-ati-org?#{query}"
      end

      puts YAML.dump(output)
    end

    desc 'Validates URLs'
    task :validate do
      URLS = load_yaml('urls.yml')

      def parse(url)
        document = client.get(url).body
        document.xpath('//div[@class="panel panel-default"]').each do |div|
          panel_heading = div.at_xpath('./div[@class="panel-heading"]')
          unless panel_heading.text == 'N/A'
            organization = div.at_xpath('./div[@class="panel-body"]//span').text
            number = panel_heading.at_xpath('.//span').text
            begin
              expected = URLS.fetch("#{organization}-#{number}")
              actual = div.at_xpath('.//@href').value.sub(/(?<=email=)(.+)/){$1.downcase}
              unless actual == expected
                puts "\n#{expected.inspect} expected on #{url}, got\n#{actual.inspect}"
              end
            rescue KeyError => e
              puts e
            end
          end
        end

        link = document.at_xpath('//li[@class="next"]//@href')
        if link
          print '.'
          parse("http://open.canada.ca#{link.value}")
        end
      end

      url = 'http://open.canada.ca/en/search/ati'
      parse(url)
    end
  end
end
