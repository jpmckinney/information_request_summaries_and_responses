require 'csv'
require 'digest/sha1'
require 'open3'

require 'docsplit'
require 'fog'
require 'nokogiri'
require 'oxcelix'
require 'pupa'
require 'rails-html-sanitizer'
require 'spreadsheet'
require 'zip'

require_relative 'aws_store'
require_relative 'download_store'
require_relative 'sort'

Mongo::Logger.logger.level = Logger::WARN

class InformationResponse
  include Pupa::Model
  include Pupa::Concerns::Timestamps

  attr_accessor :id, :division_id, :title, :identifier, :position, :abstract,
    :organization, :applicant_type, :processing_fee, :date, :decision, :url,
    :number_of_pages, :download_url, :letters, :notes, :files, :comments
  dump :id, :division_id, :title, :identifier, :position, :abstract,
    :organization, :applicant_type, :processing_fee, :date, :decision, :url,
    :number_of_pages, :download_url, :letters, :notes, :files, :comments

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

  class << self
    attr_accessor :jurisdiction_code
  end

  attr_reader :download_store

  def initialize(*args)
    super
    @download_store = DownloadStore.new(File.expand_path(File.join('downloads', self.class.jurisdiction_code), Dir.pwd))
  end

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
        file['byte_size'] = download_store.size(path)

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
          else
            info("#{path}: can't get number of pages, number of rows or duration")
          end
        end
      end
    else
      error("#{path}: unrecognized media type")
    end
  end

  def determine_if_scanned(file, path, remove)
    if download_store.exist?(path) && file.fetch('media_type') == 'application/pdf'
      unless file.key?('scan')
        info(path)
        Open3.popen3("pdftotext #{Shellwords.escape(download_store.path(path))} -") do |stdin,stdout,stderr,wait_thr|
          if Process::Waiter === wait_thr || wait_thr.value.success? # not sure how to handle `Process::Waiter`
            output = stdout.read.gsub(/\p{Space}+/, ' ')
            remove.each do |pattern|
              output.gsub!(pattern, '')
            end
            file['scan'] = output.gsub(/\p{Space}+/, ' ').strip.size <= 1000
          else
            error("#{path}: #{stderr.read}")
          end
        end
      end
    end
  end

  def upload
    aws_store = AWSStore.new('information_requests', ENV['AWS_BUCKET'], ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    delimiter_re = /(\d)(?=(\d\d\d)+(?!\d))/

    # An entire year is very large (GBs), so upload months and smaller.
    download_store.glob('*/**/*').each do |directory|
      if ENV['prefix'].nil? || directory.start_with?(ENV['prefix'])
        if download_store.directory?(directory)
          aws_path = File.join(self.class.jurisdiction_code, "#{directory}.zip")

          unless aws_store.exist?(aws_path)
            info("writing #{aws_path}")
            pattern = %r{\A#{File.dirname(directory)}/}

            io = Zip::OutputStream.write_buffer do |zipfile|
              download_store.glob(File.join(directory, '**/*')).each do |file|
                if download_store.file?(file)
                  zipfile.put_next_entry(file.sub(pattern, ''))
                  zipfile.write download_store.read(file)
                end
              end
            end

            info("uploading #{aws_path} (#{io.size.to_s.gsub(delimiter_re){|d| "#{d},"}})")
            begin
              aws_store.write(aws_path, io.string)
            rescue Excon::Errors::SocketError => e
              error(e)
            end
          end
        end
      end
    end
  end
end
