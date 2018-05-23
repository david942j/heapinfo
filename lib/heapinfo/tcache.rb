require 'heapinfo/arena'

module HeapInfo
  # Fetch tcache structure and show its content.
  class Tcache
    # #define TCACHE_MAX_BINS 64
    MAX_BINS = 64
    # Instantiate a {HeapInfo::Tcache} object.
    #
    # @param [Integer] base Base address of +tcache+.
    # @param [Integer] size_t Either 8 or 4.
    # @param [Proc] dumper For dumping more data.
    def initialize(base, size_t, dumper)
      @base = base
      @size_t = size_t
      @dumper = dumper
    end

    # Pretty dump of tcache entries.
    #
    # @return [String] Tcache entries that wrapper with color codes.
    def layouts
      entries.map(&:inspect).join
    end

    private

    def entries
      Array.new(MAX_BINS) do |idx|
        TcacheEntry.new(@size_t, @base + 64 + @size_t * idx, @dumper, head: true).tap { |f| f.index = idx }
      end
    end
  end

  # A tcache entry.
  #
  # Though this class inherited from {Chunk} ({Fastbin}), tcache entries are *not* chunks.
  class TcacheEntry < Fastbin
    # For pretty inspect.
    #
    # @return [String]
    #   Empty string is returned if this entry contains nothing.
    def inspect
      return '' if fd_of(@base).zero? # empty
      super
    end

    private

    # Hack +fd_of+ method here then everything works.
    def fd_of(ptr)
      addr_of(ptr, 0)
    end
  end
end
