require 'bundler/setup'

require 'open3'
require 'faraday-cookie_jar'

require_relative 'lib/utils'

class BC < Processor
  DIVISION_ID = 'ocd-division/country:ca/province:bc'

  def get_identifier(text)
    text.match(/\AFOI Request - (\S+)\z/)[1]
  end

  def get_date(text)
    DateTime.strptime(text, '%B %e, %Y').strftime('%Y-%m-%d')
  end

  def scrape_responses
    client.options.params_encoder = Faraday::FlatParamsEncoder

    headers = {
      applicant_type: 'Applicant Type',
      organization: 'Ministry',
      fees_paid: 'Fees paid by applicant',
      date: 'Publication Date',
      letters: 'Letters',
      notes: 'Notes',
      files: 'Files',
    }
    # e.g. http://www.openinfo.gov.bc.ca/ibc/search/detail.page?P110=recorduid%3A3032724&config=ibc&title=FOI+Request+-+FIN-2011-00184
    possible_headers = headers.values
    required_headers = headers.values - ['Letters', 'Notes', 'Files']

    # Set cookie.
    get('http://openinfo.gov.bc.ca/')
    base_url = 'http://www.openinfo.gov.bc.ca/ibc/search/results.page?config=ibc&P110=dc.subject:FOI%20Request&P110=high_level_subject:FOI%20Request&sortid=1&rc=1&as_ft=i&as_filetype=html'

    # Set the URLs to scrape.
    if options.key?('date')
      year, month = options['date'].split('-', 2)
      if month
        month.sub!(/\A0/, '')
        urls = [
          "#{base_url}&P110=month:#{month}&P110=year:#{year}&size=100",
        ]
      else
        url = "#{base_url}&date=30"
        urls = get(url).xpath("//select[@id='monthSort']/option[position() > 1]/@value[contains(., 'year:#{year}')]").map do |value|
          "http://www.openinfo.gov.bc.ca#{value}&size=100"
        end
      end
    else
      url = "#{base_url}&date=30"
      urls = get(url).xpath('//select[@id="monthSort"]/option[position() > 1]/@value').map do |value|
        "http://www.openinfo.gov.bc.ca#{value}&size=100"
      end
    end

    urls.each do |url|
      index = 0

      begin
        list = get("#{url}&index=#{index}")

        list.xpath('//tr')[1..-1].each do |tr| # `[position() > 1]` doesn't work
          tds = tr.xpath('./td')

          # Get the response's properties from the list page.
          title = tds[0].text
          detail_url = "http://www.openinfo.gov.bc.ca#{tds[0].at_xpath('.//@href').value.strip}"
          list_properties = {
            id: detail_url.match(/\brecorduid:([^&]+)/)[1],
            title: title,
            identifier: get_identifier(title),
            url: detail_url,
            abstract: tds[1].text.chomp('...'),
            date: get_date(tds[2].text),
            organization: tds[3].text,
          }

          begin
            div = get(list_properties[:url]).xpath('//div[@class="saquery_searchResult_ibc"]')

            # Get the response's properties from its detail page.
            title = div.xpath('./h3').text
            detail_properties = {
              title: title,
              identifier: get_identifier(title),
              abstract: div.xpath('./p[1]/following-sibling::p | ./p[1]/following-sibling::h4').slice_before{|e| e.name == 'h4'}.first.map(&:text).join("\n\n"),
            }
            headers.each do |property,label|
              b = div.at_xpath(".//b[contains(.,'#{label}')]")
              if [:letters, :notes, :files].include?(property)
                if b
                  lis = b.xpath('../following-sibling::ul[1]/li')

                  lis.each do |li|
                    a = li.at_xpath('./a')

                    detail_properties[property] ||= []
                    detail_properties[property] << {
                      title: a.text,
                      url: a[:href],
                      byte_size: li.text.match(/\(([0-9.]+MB)\)/)[1],
                    }
                  end

                  assert("expected #{property}"){!lis.empty?} # Ensure XPath matches.
                end
              else
                text = b.at_xpath("./following-sibling::text()").text

                detail_properties[property] = case property
                when :fees_paid
                  Float(text.sub!(/\A\$/, '')) && text
                when :date
                  get_date(text)
                else
                  text
                end
              end
            end

            # Check for any missing or unexpected headers.
            actual = div.xpath('.//b').map{|b| b.text.strip.chomp(':')}
            assert("unexpected: #{(actual - possible_headers).join(', ')}\nmissing: #{(required_headers - actual).join(', ')}"){(required_headers - actual).empty?}

            # Check the consistency of abstracts.
            expected = list_properties[:abstract]
            actual = detail_properties[:abstract]
            assert("#{expected} expected to be part of\n#{actual}"){actual[expected]}

            # Check the consistency of other properties from the list page.
            [:title, :identifier, :date, :organization].each do |property|
              expected = list_properties[property]
              actual = detail_properties[property]
              assert("#{expected} expected for #{property}, got\n#{actual}"){actual == expected}
            end

            # Check that the response has some attachments.
            assert("expected letters, notes or files, got none"){detail_properties.slice(:letters, :notes, :files).any?}

            properties = {
              division_id: DIVISION_ID,
            }.merge(list_properties.merge(detail_properties))
            dispatch(InformationResponse.new(properties))

            if properties[:notes]
              p properties
            end
          rescue NoMethodError => e
            error("#{list_properties[:url]}: #{e}\n#{e.backtrace.join("\n")}")
          end
        end

        index += 100
      end while list.at_xpath('//div[@class="pagination"]//a[contains(.,"►")]')
    end
  end

  def download
    store = DownloadStore.new(File.expand_path(File.join('downloads', 'ca_bc'), Dir.pwd))
    connection.raw_connection['information_responses'].find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
      date = Date.parse(response['date'])
      year = date.strftime('%Y')
      month = date.strftime('%m')

      ['letters', 'notes', 'files'].each do |property|
        if response[property]
          response[property].each do |file|
            path = File.join(year, month, response['id'], file['title'])
            unless store.exist?(path)
              begin
                store.write(path, get(URI.escape(file['url'])))
              rescue Faraday::ResourceNotFound
                warn("404 #{file['url']}")
              end
            end
          end
        end
      end
    end
  end

  def number_of_pages
    store = DownloadStore.new(File.expand_path(File.join('downloads', 'ca_bc'), Dir.pwd))
    collection = connection.raw_connection['information_responses']
    collection.find(division_id: DIVISION_ID).no_cursor_timeout.each do |response|
      response['number_of_pages'] = 0

      ['letters', 'notes', 'files'].each do |property|
        if response[property]
          response[property].each do |file|
            path = File.join(response['id'], file['title'])
            if File.extname(path).downcase == '.pdf' && store.exist?(path)
              Open3.popen3("pdfinfo #{Shellwords.escape(store.path(path))}") do |stdin,stdout,stderr,wait_thr|
                if wait_thr.value.success?
                  file['number_of_pages'] = Integer(stdout.read.match(/^Pages: +(\d+)$/)[1])
                  # The response is sometimes in the incorrect section on the website.
                  if file['title'][/pac[ka]{2}ge|records/i] # /letter|email/ for letters, /note/ for notes
                    response['number_of_pages'] += file['number_of_pages']
                  end
                else
                  error("#{path}: #{stderr.read}")
                end
              end
            end
          end
        end
      end

      collection.update_one({_id: response['_id']}, response)
    end
  end
end

BC.add_scraping_task(:responses)

runner = Pupa::Runner.new(BC)
runner.add_action(name: 'download', description: 'Download responses')
runner.add_action(name: 'number_of_pages', description: 'Calculate the number of pages disclosed')
runner.run(ARGV, faraday_options: {follow_redirects: {limit: 5}})
