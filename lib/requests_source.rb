# cron:upload and datasets:download
class RequestsSource
  class << self
    # @return [Array<RequestsSource>] all sources
    attr_reader :all

    # Returns the sources that match the criteria.
    #
    # @param [Hash] criteria Key-value pairs in which the key is an attribute
    #   and the value is an expected attribute value. If the value is an array,
    #   the source's attribute value must equal one of the items in the array.
    # @return [Array<RequestSource>] the matching sources
    def select(criteria)
      all.select do |source|
        criteria.all? do |attribute,expected|
          actual = source.send(attribute)
          if Array === expected
            value.include?(actual)
          else
            actual == expected
          end
        end
      end
    end

    # Returns an HTTP client.
    #
    # @return [Pupa::Processor::Client.new] an HTTP client
    def client
      @client ||= Pupa::Processor::Client.new(cache_dir: '_cache', expires_in: 604800, level: 'WARN') # 1 week
    end
  end

  @all = []

  # @return [String] the source's jurisdiction code, e.g. "ca_on_toronto"
  attr_accessor :jurisdiction_code
  # @return [String] the source's human-readable source URL
  attr_accessor :source_url
  # @return [String,nil] the XPath selector for download URLs
  attr_accessor :xpath
  # @return [Array<String>] a list of download URLs
  attr_accessor :download_urls
  # @return [String] a character encoding
  attr_accessor :encoding
  # @return [Proc] a method to filter out non-data files
  attr_accessor :filter
  # @return [Proc] a method to return the command to transform a file
  attr_accessor :command

  # Initializes a source and adds it to the list of sources.
  #
  # @param [Hash] attributes attributes
  def initialize(attributes)
    self.class.all << self
    @download_urls = []
    @filter = ->(input) { true }
    @command = ->(input, output) { "in2csv #{Shellwords.escape(input)} | csvcut -x" }
    attributes.each do |key,value|
      send("#{key}=", value)
    end
  end

  # Returns an HTTP client.
  #
  # @return [Pupa::Processor::Client.new] an HTTP client
  def client
    self.class.client
  end

  # Returns a directory.
  #
  # @return [String] a directory
  def directory
    File.join('wip', jurisdiction_code)
  end

  # Downloads files and, if necessary, transforms them to CSV.
  def download_and_transform!
    FileUtils.mkdir_p(directory)

    urls = get_download_urls

    urls.each do |url|
      input = File.join(directory, basename(url))
      begin
        download(url, input)
        transform(input)
      rescue Faraday::Error => e
        $stderr.puts "#{e.response[:status]} #{url}"
      end
    end

    stack
  end

private

  # Scrapes, if necessary, and returns all download URLs.
  #
  # @return [Array<String>] all download URLs
  def get_download_urls
    urls = download_urls
    if xpath
      parsed = URI.parse(source_url)
      client.get(source_url).body.xpath(xpath).each do |href|
        value = href.value
        if value[' '] # ca_on_toronto has unescaped spaces
          value = URI.escape(href.value)
        end
        urls << "#{parsed.scheme}://#{parsed.host}#{URI.parse(value).path}"
      end
    end
    urls
  end

  # Downloads a remote file to a local file.
  #
  # @param [String] remote a remote URL
  # @param [String] local a local filename
  def download(remote, local)
    File.open(local, 'w') do |f|
      f.write(client.get(remote).body)
    end
  end

  # Transform an input file into a CSV file.
  #
  # @param [String] input an input filename
  def transform(input)
    if %w(.xls .xlsx).include?(File.extname(input)) && filter.call(input)
      output = input.sub(/\.xlsx?\z/, '.csv')
      cmd = "#{command.call(input, output)} > #{Shellwords.escape(output)}"
      stdout, stderr, status = Open3.capture3(cmd)
      unless stderr.empty?
        $stderr.puts "#{input}: #{stderr}"
      end
      if status.success?
        print '.'
      end
    end
  end

  # Stacks CSV files.
  def stack
    arguments = ''

    if encoding
      arguments << " -e #{encoding}"
    end

    inputs = Dir[File.join(directory, '*.csv')].reject { |path| path['data.csv'] }.map { |path| Shellwords.escape(path) }.join(' ')
    command = "csvstack#{arguments} #{inputs} > #{Shellwords.escape(File.join(directory, 'data.csv'))}"
    success = system(command)

    unless success
      puts command
    end
  end

  # Returns the local basename for a URL.
  #
  # @param [String] url a URL
  def basename(url)
    parsed = URI.parse(url)
    if %w(.csv .xls .xlsx .doc).include?(File.extname(parsed.path))
      File.basename(parsed.path)
    else
      'input.csv'
    end
  end
end

# @see https://docs.google.com/spreadsheets/d/1WQ6kWL5hAEThi31ZQtTZRX5E8_Y9BwDeEWATiuDakTM/edit#gid=0
[{
  jurisdiction_code: 'ca',
  source_url: 'http://open.canada.ca/data/en/dataset/0797e893-751e-4695-8229-a5066e4fe43c',
  download_urls: [
    'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
  ],
}, {
  jurisdiction_code: 'ca_ab_calgary',
  source_url: 'http://www.calgary.ca/CA/City-Clerks/Pages/Freedom-of-Information-and-Protection-of-Privacy/Freedom-of-Information-and-Protection-of-Privacy.aspx',
  xpath: '//div[@class="cocis-rte-Element-DIV-Sidebar"]//@href',
  command: ->(input, output) {
    # Note: Calgary's 2016 XLSX file is not a ZIP file. You must open it in Excel and re-save it.
    "in2csv #{Shellwords.escape(input)} | csvcut -x | grep -v b,c,d,e,f,g,h,i,j"
  },
}, {
  jurisdiction_code: 'ca_ab_edmonton',
  source_url: 'https://data.edmonton.ca/City-Administration/FOIP-Requests/u2wt-gn9w',
  download_urls: [
    'https://data.edmonton.ca/api/views/u2wt-gn9w/rows.csv?accessType=DOWNLOAD',
  ],
}, {
  jurisdiction_code: 'ca_nl',
  source_url: 'http://opendata.gov.nl.ca/public/opendata/page/?page-id=datasetdetails&id=222',
  download_urls: [
    'http://opendata.gov.nl.ca/public/opendata/filedownload/?file-id=6864',
  ],
  encoding: 'iso-8859-1',
}, {
  jurisdiction_code: 'ca_on_burlington',
  source_url: 'http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0',
  download_urls: [
    'http://cob.burlington.opendata.arcgis.com/datasets/ee3ccd488aef46c7b1dca1fc1062f3e5_0.csv',
  ],
}, {
  jurisdiction_code: 'ca_on_greater_sudbury',
  source_url: 'http://opendata.greatersudbury.ca/datasets/ef090ab4ce104baabadeb4f6d3f0b807_0', # http://opendata.greatersudbury.ca/datasets/2fcda89184b0436b8dd05f5dd2f31bad_0
  download_urls: [
    'http://opendata.greatersudbury.ca/datasets/ef090ab4ce104baabadeb4f6d3f0b807_0.csv',
    'http://opendata.greatersudbury.ca/datasets/2fcda89184b0436b8dd05f5dd2f31bad_0.csv',
  ],
}, {
  jurisdiction_code: 'ca_on_toronto',
  source_url: 'http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD',
  xpath: '//div[@class="panel-body"]//@href',
  filter: ->(input) { !input['_Readme.xls'] },
  command: ->(input, output) {
    # The files from 2011 contain two extra columns.
    arguments = input['2011'] ? ' -C Jacket_Number,Exemption' : ''
    "in2csv #{Shellwords.escape(input)} | csvcut -x #{arguments}"
  },
}, {
  jurisdiction_code: 'ca_on_waterloo_region',
  source_url: 'http://www.regionofwaterloo.ca/en/regionalGovernment/Freedom_of_Information_Requests.asp',
  xpath: '//table[@class="datatable"]//ul//@href',
}].map do |attributes|
  RequestsSource.new(attributes)
end
