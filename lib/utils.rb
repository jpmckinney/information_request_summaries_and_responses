require 'csv'
require 'digest/sha1'
require 'open3'

require 'nokogiri'
require 'oxcelix'
require 'pupa'
require 'spreadsheet'

require_relative 'sort'

Mongo::Logger.logger.level = Logger::WARN

class InformationResponse
  include Pupa::Model
  include Pupa::Concerns::Timestamps

  attr_accessor :division_id, :id, :title, :identifier, :url, :abstract,
    :decision, :date, :number_of_pages, :organization, :applicant_type,
    :fees_paid, :letters, :notes, :files, :download_url, :comments
  dump :division_id, :id, :title, :identifier, :url, :abstract, :decision,
    :date, :number_of_pages, :organization, :applicant_type, :fees_paid,
    :letters, :notes, :files, :download_url, :comments

  def fingerprint
    to_h.slice(:division_id, :id)
  end

  def to_s
    id || identifier
  end
end

class Processor < Pupa::Processor
  MEDIA_TYPES = {
    'application/pdf' => '.pdf',
    'application/vnd.ms-excel' => '.xls',
    'application/vnd.ms-excel.sheet.macroEnabled.12' => '.xlsm',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => '.xlsx',
    'audio/mpeg' => '.mp3',
    'audio/wav' => '.wav',
    'image/tiff' => '.tif',
    'text/csv' => '.csv',
    'video/mp4' => '.mp4',
  }.freeze

  DURATION_UNITS = {
    'h' => 3600,
    'mn' => 60,
    's' => 1,
    'ms' => 0.001,
  }.freeze

  attr_reader :download_store

  def assert(message)
    error(message) unless yield
  end

  def collection
    connection.raw_connection['information_responses']
  end

  def calculate_document_size(file, path)
    media_type, _ = MEDIA_TYPES.find{|_,extension| File.extname(path).downcase == extension}
    if media_type
      file['media_type'] = media_type

      if download_store.exist?(path)
        file['byte_size'] = File.size(download_store.path(path))

        # Avoid running commands if unnecessary.
        unless file.key?('number_of_pages') || file.key?('number_of_rows') || file.key?('duration')
          info("get length of #{path}")
          case file['media_type']
          when 'application/pdf'
            Open3.popen3("pdfinfo #{Shellwords.escape(download_store.path(path))}") do |stdin,stdout,stderr,wait_thr|
              if wait_thr.value.success?
                file['number_of_pages'] = Integer(stdout.read.match(/^Pages: +(\d+)$/)[1])
              else
                error("#{path}: #{stderr.read}")
              end
            end
          when 'image/tiff'
            Open3.popen3("tiffinfo #{Shellwords.escape(download_store.path(path))}") do |stdin,stdout,stderr,wait_thr|
              if Process::Waiter === wait_thr || wait_thr.value.success? # not sure how to handle `Process::Waiter`
                output = stdout.read
                if output['Subfile Type: multi-page document']
                  file['number_of_pages'] = Integer(output.scan(/\bPage Number: (\d+)/).flatten.last) + 1
                else
                  file['number_of_pages'] = 1
                end
              else
                error("#{path}: #{stderr.read}")
              end
            end
          when 'application/vnd.ms-excel'
            file['number_of_rows'] = Spreadsheet.open(download_store.path(path)).worksheets.reduce(0) do |memo,sheet|
              memo + sheet.rows.count{|row| !row.empty?}
            end
          when 'application/vnd.ms-excel.sheet.macroEnabled.12', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            file['number_of_rows'] = Oxcelix::Workbook.new(download_store.path(path)).sheets.reduce(0) do |memo,sheet|
              if Hash === sheet # empty sheet?
                memo
              else
                memo + sheet.row_size
              end
            end
          when 'text/csv'
            file['number_of_rows'] = CSV.read(download_store.path(path)).size
          when 'audio/mpeg', 'audio/wav', 'video/mp4'
            Open3.popen3("mediainfo #{Shellwords.escape(download_store.path(path))}") do |stdin,stdout,stderr,wait_thr|
              if wait_thr.value.success?
                file['duration'] = stdout.read.match(/^Duration +: (.+)$/)[1].scan(/(\d+)(\w+)/).reduce(0) do |memo,(value,unit)|
                  memo + Integer(value) * DURATION_UNITS.fetch(unit)
                end
              else
                error("#{path}: #{stderr.read}")
              end
            end
          end
        end
      end
    else
      error("#{path}: unrecognized media type")
    end
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
      Dir['**/*']
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
