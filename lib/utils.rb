require 'csv'
require 'digest/sha1'
require 'open3'

require 'nokogiri'
require 'pupa'

require_relative 'sort'

Mongo::Logger.logger.level = Logger::WARN

class InformationResponse
  include Pupa::Model
  include Pupa::Concerns::Timestamps

  attr_accessor :division_id, :id, :title, :identifier, :url, :abstract, :date,
    :organization, :applicant_type, :fees_paid, :letters, :notes, :files,
    :download_url, :comments
  dump :division_id, :id, :title, :identifier, :url, :abstract, :date,
    :organization, :applicant_type, :fees_paid, :letters, :notes, :files,
    :download_url, :comments

  def fingerprint
    to_h.slice(:division_id, :id)
  end

  def to_s
    id
  end
end

class Processor < Pupa::Processor
  def assert(message)
    error(message) unless yield
  end

  def collection
    connection.raw_connection['information_responses']
  end
end

# Stores data downloads on disk.
#
# @see ActiveSupport::Cache::FileStore
class DownloadStore < Pupa::Processor::DocumentStore::FileStore
  # Returns all file names in the storage directory.
  #
  # @return [Array<String>] all keys in the store
  def entries
    Dir.chdir(@output_dir) do
      Dir['*']
    end
  end

  # Returns the contents of the file with the given name.
  #
  # @param [String] name a key
  # @return [Hash] the value of the given key
  def read(name)
    File.open(path(name)) do |f|
      f.read
    end
  end

  # Writes the value to a file with the given name.
  #
  # @param [String] name a key
  # @param [Hash,String] value a value
  def write(name, value)
    FileUtils.mkdir_p(File.dirname(path(name)))
    File.open(path(name), 'w') do |f|
      f.write(value)
    end
  end

  # Deletes all files in the storage directory.
  def clear
    Dir[File.join(@output_dir, '*')].each do |path|
      File.delete(path)
    end
  end

  # Returns the byte size of the file.
  #
  # @param [String] name a key
  # @return [Integer] the file size in bytes
  def size(name)
    File.size(path(name))
  end

  def sha1(name)
    Digest::SHA1.file(path(name)).hexdigest
  end
end
