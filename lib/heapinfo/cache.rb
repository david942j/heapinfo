require 'digest'
module HeapInfo
  # Self implment file-base cache manager.
  #
  # Values are recorded in files based on <tt>Marshal</tt>.
  module Cache
    # Directory for caching files.
    # e.g. HeapInfo will record main_arena_offset for glibc(s)
    CACHE_DIR = File.join(ENV['HOME'], '.cache/heapinfo')

    # Get the key for store libc offsets
    #
    # @param [String] libc_path The realpath to libc file
    # @return [String] The key for cache read/write.
    def self.key_libc_offset(libc_path)
      File.join('libc', Digest::MD5.hexdigest(IO.binread(libc_path)), 'offset')
    end

    # Write cache to file.
    #
    # @param [String] key In file path format, only accept <tt>[\w\/]</tt> to prevent horrible things.
    # @param [Object] value <tt>value</tt> will be stored with <tt>#Marshal::dump</tt>.
    # @return [Boolean] true
    def self.write(key, value)
      filepath = realpath key
      FileUtils.mkdir_p(File.dirname(filepath))
      IO.binwrite(filepath, Marshal.dump(value))
      true
    end

    # Read cache from file.
    #
    # @param [String] key In file path format, only accept <tt>[\w\/]</tt> to prevent horrible things.
    # @return [Object, NilClass] value that recorded, return <tt>nil</tt> when cache miss.
    def self.read(key)
      filepath = realpath key
      return unless File.file?(filepath)
      Marshal.load(IO.binread(filepath))
    rescue
      nil # handle if file content invalid
    end

    # @param [String] key
    # @return [String] Prepend with <tt>CACHE_DIR</tt>
    def self.realpath(key)
      raise ArgumentError, 'Invalid key(file path)' if key =~ %r{[^\w/]}
      File.join(CACHE_DIR, key)
    end

    # @return [void]
    def self.init
      FileUtils.mkdir_p(CACHE_DIR)
    rescue
      # To prevent ~/ is not writable.
      send(:remove_const, :CACHE_DIR)
      const_set(:CACHE_DIR, File.join(HeapInfo::TMP_DIR, '.cache/heapinfo'))
    end

    # Clear the cache directory.
    # @return [void]
    def self.clear_all
      FileUtils.rm_rf CACHE_DIR
    end
    init
  end
end
