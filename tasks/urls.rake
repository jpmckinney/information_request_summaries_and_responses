namespace :urls do
  desc 'Prints URLs to forms'
  task :get do
    corrections = CORRECTIONS.invert

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
    # url = 'http://open.canada.ca/en/search/ati?keyword=&page=2819'
    parse(url)
  end
end
