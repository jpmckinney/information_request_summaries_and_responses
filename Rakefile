require 'csv'
require 'erb'
require 'open-uri'

require 'nokogiri'
require 'pupa'
require 'safe_yaml'
require 'unicode_utils/downcase'

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

Dir['tasks/*.rake'].each { |r| import r }
