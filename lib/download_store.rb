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

  # Moves the file.
  #
  # @param [String] old_name the old key
  # @param [String] new_name the new key
  def move(old_name, new_name)
    FileUtils.mkdir_p(File.dirname(path(new_name)))
    FileUtils.mv(path(old_name), path(new_name))
  end

  # Deletes all files in the storage directory.
  def clear
    Dir[File.join(@output_dir, '*')].each do |path|
      File.delete(path)
    end
  end

  # Returns files names matching the pattern in the storage directory.
  #
  # @param [String] pattern a pattern
  # @return [Array<String>] matching keys in the store
  def glob(pattern)
    Dir.chdir(@output_dir) do
      Dir[pattern]
    end
  end

  # Returns whether the file is a directory.
  #
  # @param [String] name a key
  # @return [Boolean] whether the file is a directory
  def directory?(name)
    File.directory?(path(name))
  end

  # Returns whether the file is a regular file.
  #
  # @param [String] name a key
  # @return [Boolean] whether the file is a regular file
  def file?(name)
    File.file?(path(name))
  end

  # Returns the byte size of the file.
  #
  # @param [String] name a key
  # @return [Integer] the file size in bytes
  def size(name)
    File.size(path(name))
  end

  # Returns the SHA1 hexidecimal digest of the file.
  #
  # @param [String] name a key
  # @return [Integer] the SHA1 hexidecimal digest of the file
  def sha1(name)
    Digest::SHA1.file(path(name)).hexdigest
  end
end
