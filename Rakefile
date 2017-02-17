require 'bundler/setup'

require 'csv'
require 'erb'
require 'open-uri'
require 'open3'

require 'faraday-cookie_jar'
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
  $stderr.puts message unless yield
end

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: '_cache', expires_in: 604800, level: 'WARN') # 1 week
end

def load_yaml(basename)
  YAML.load(File.read(File.join('support', basename)))
end

require_relative 'lib/aws_store'
require_relative 'lib/constants'
require_relative 'lib/requests_source'
require_relative 'lib/templates'
require_relative 'lib/sort'

Dir['tasks/*.rake'].each { |r| import r }
