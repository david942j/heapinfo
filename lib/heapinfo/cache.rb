require 'digest'
module HeapInfo
  # Self implment file-base cache manager.
  #
  # Values are recorded in files based on +Marshal+.
  module Cache
    # Directory for caching files.
    # e.g. HeapInfo will record main_arena_offset for glibc(s).
    CACHE_DIR = File.join(ENV['HOME'], '.cache/heapinfo')

    # Define class methods.
    module ClassMethods
      # Get the key for store libc offsets.
      #
      # @param [String] libc_path The realpath to libc file.
      # @return [String] The key for cache read/write.
      def key_libc_offset(libc_path)
        File.join('libc', Digest::MD5.hexdigest(IO.binread(libc_path)), 'offset')
      end

      # Write cache to file.
      #
      # @param [String] key In file path format, only accept +[\w/]+ to prevent horrible things.
      # @param [Object] value +value+ will be stored with +Marshal#dump+.
      # @return [Boolean] true
      def write(key, value)
        filepath = realpath(key)
        FileUtils.mkdir_p(File.dirname(filepath))
        IO.binwrite(filepath, Marshal.dump(value))
        true
      end

      # Read cache from file.
      #
      # @param [String] key In file path format, only accept +[\w\/]+ to prevent horrible things.
      # @return [Object, NilClass] Value that recorded, return +nil+ when cache miss.
      def read(key)
        filepath = realpath(key)
        return unless File.file?(filepath)
        Marshal.load(IO.binread(filepath))
      rescue
        nil # handle if file content invalid
      end

      # Clear the cache directory.
      # @return [void]
      def clear_all
        FileUtils.rm_rf(CACHE_DIR)
      end

      private

      # @return [void]
      def init
        FileUtils.mkdir_p(CACHE_DIR)
      rescue
        # To prevent ~/ is not writable.
        send(:remove_const, :CACHE_DIR)
        const_set(:CACHE_DIR, File.join(HeapInfo::TMP_DIR, '.cache/heapinfo'))
        FileUtils.mkdir_p(CACHE_DIR)
      end

      # @param [String] key
      # @return [String] Prepend with {HeapInfo::Cache::CACHE_DIR}.
      def realpath(key)
        raise ArgumentError, 'Invalid key(file path)' if key =~ %r{[^\w/]}
        File.join(CACHE_DIR, key)
      end
    end

    extend ClassMethods
    init
  end
end
