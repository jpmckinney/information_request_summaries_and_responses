require 'bundler/setup'

require 'csv'
require 'erb'
require 'open-uri'

require 'fog'
require 'nokogiri'
require 'pupa'
require 'safe_yaml'
require 'shellwords'
require 'unicode_utils/downcase'
require 'whos_got_dirt'

Mongo::Logger.logger.level = Logger::WARN
SafeYAML::OPTIONS[:default_mode] = :safe

def assert(message)
  raise message unless yield
end

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: '_cache', expires_in: 604800, level: 'WARN') # 1 week
end

def load_yaml(basename)
  YAML.load(File.read(File.join('support', basename)))
end

def url_to_basename(url)
  %w(.csv .xls .xlsx).include?(File.extname(url)) ? File.basename(url) : 'data.csv'
end

def download_multiple(jurisdiction, url, xpath)
  FileUtils.mkdir_p(File.join('wip', jurisdiction))
  parsed = URI.parse(url)
  client.get(url).body.xpath(xpath).each do |href|
    path = href.value
    File.open(File.join(File.join('wip', jurisdiction), File.basename(path)), 'w') do |f|
      f.write(client.get("#{parsed.scheme}://#{parsed.host}#{URI.escape(path)}").body)
    end
  end
end

def stack_multiple(jurisdiction)
  inputs = send("#{jurisdiction}_glob", '*.csv').reject{|path| path['data.csv']}.map{|path| Shellwords.escape(path)}.join(' ')
  `csvstack #{inputs} > #{File.join('wip', jurisdiction, 'data.csv')}`
end

require_relative 'lib/aws_store'
require_relative 'lib/constants'
require_relative 'lib/templates'
require_relative 'lib/sort'

Dir['tasks/*.rake'].each { |r| import r }
