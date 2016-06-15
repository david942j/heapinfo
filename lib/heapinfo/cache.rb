module HeapInfo

  # Self implment file-base cache manager.
  #
  # Values are recorded in files based on <tt>Marshal</tt>
  module Cache
    # Directory for caching files.
    # e.g. HeapInfo will record main_arena_offset for glibc(s)
    CACHE_DIR = '~/.cache/heapinfo'
    begin
      # To prevent ~/ is not writable.
      FileUtils.mkdir_p(CACHE_DIR)
    rescue
      CACHE_DIR = File.join(HeapInfo::TMP_DIR, 'cache')
    end

    # Write cache to file.
    #
    # @param [String] key In file path format, only accept <tt>[\w\/]</tt> to prevent horrible things.
    # @param [Object] value <tt>value</tt> will be stored with <tt>#Marshal::dump</tt>.
    # @return [Boolean] true
    def self.write(key, value)
      filepath = realpath key
      FileUtils.mkdir_p(File.dirname filepath)
      IO.binwrite(filepath, Marshal::dump(value))
      true
    end

    # Read cache from file.
    #
    # @param [String] key In file path format, only accept <tt>[\w\/]</tt> to prevent horrible things.
    # @return [Object, NilClass] value that recorded, return <tt>nil</tt> when cache miss.
    def self.read(key)
      filepath = realpath key
      return unless File.file? filepath
      Marshal::load filepath
    rescue
      nil # handle if file content invalid
    end

  private
    def self.realpath(key)
      raise ArgumentError.new('Invalid key(file path)') if key =~ /[^\w\/]/
      File.join(CACHE_DIR, key)
    end
  end
end
