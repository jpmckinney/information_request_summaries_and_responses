require 'csv'
require 'erb'
require 'open-uri'

require 'nokogiri'
require 'pupa'
require 'safe_yaml'
require 'unicode_utils/downcase'

SafeYAML::OPTIONS[:default_mode] = :safe

CORRECTIONS = {
  # Web => CSV
  'Canada Science and Technology Museum' => 'Canada Science and Technology Museums Corporation',
  'Civilian Review and Complaints Commission for the RCMP' => 'Commission for Public Complaints Against the RCMP',
}

def assert(message)
  raise message unless yield
end

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: '_cache', expires_in: 604800, level: 'WARN') # 1 week
end

def load_yaml(basename)
  YAML.load(File.read(File.join('data', basename)))
end

Dir['tasks/*.rake'].each { |r| import r }
