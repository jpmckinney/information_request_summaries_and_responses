require 'csv'
require 'yaml'

require 'nokogiri'
require 'pupa'
require 'safe_yaml'

SafeYAML::OPTIONS[:default_mode] = :safe

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: File.expand_path('_cache', Dir.pwd), expires_in: 604800) # 1 week
end

output_dir = File.expand_path('_data', Dir.pwd)
URLS = YAML.load(File.read(File.join(output_dir, 'urls.yml')))

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
          puts "#{expected} expected, got\n#{actual}"
        end
      rescue KeyError => e
        puts e
      end
    end
  end

  link = document.at_xpath('//li[@class="next"]//@href')
  if link
    parse("http://open.canada.ca#{link.value}")
  end
end

url = 'http://open.canada.ca/en/search/ati'
parse(url)
