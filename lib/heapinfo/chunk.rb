require 'heapinfo/helper'

module HeapInfo
  # The object of a heap chunk
  class Chunk
    # @return [Integer] 4 or 8 according to 32bit or 64bit, respectively.
    attr_reader :size_t
    # @return [Integer] previous chunk size
    attr_reader :prev_size
    # @return [String] chunk data
    attr_reader :data
    # @return [Integer] Base address of this chunk
    attr_reader :base

    # Instantiate a {HeapInfo::Chunk} object
    #
    # @param [Integer] size_t 4 or 8
    # @param [Integer] base Start address of this chunk
    # @param [Proc] dumper For dump more information of this chunk
    # @param [Boolean] head
    #   For specific if is fake chunk in +arena+.
    #   If +head+ is +true+, will not load +size+ and +prev_size+ (since it's meaningless)
    # @example
    #   HeapInfo::Chunk.new 8, 0x602000, ->(addr, len) { [0,0x21, 0xda4a].pack('Q*')[addr-0x602000, len] }
    #   # create a chunk with chunk size 0x21
    def initialize(size_t, base, dumper, head: false)
      raise ArgumentError, 'size_t can be either 4 or 8' unless [4, 8].include?(size_t)

      self.class.__send__(:define_method, :dump) { |*args| dumper.call(*args) }
      @size_t = size_t
      @base = base
      sz = dump(@base, size_t * 2)
      if head # no need to read size if is bin
        @data = dump(@base + size_t * 2, size_t * 4)
        return
      end
      @prev_size = Helper.unpack(size_t, sz[0, size_t])
      @size = Helper.unpack(size_t, sz[size_t..-1])
      r_size = [size - size_t * 2, size_t * 4].min # don't read too much data
      r_size = [r_size, 0].max # prevent negative size
      @data = dump(@base + size_t * 2, r_size)
    end

    # Hook +#to_s+ for pretty printing
    # @return [String]
    def to_s
      ret = Helper.color(format("#<%s:%#x>\n", self.class.to_s, @base), sev: :klass)
      ret += "flags = [#{flags.map { |f| Helper.color(":#{f}", sev: :sym) }.join(',')}]\n"
      ret += "size = #{Helper.color(format('%#x', size))} (#{bintype})\n"
      ret += "prev_size = #{Helper.color(format('%#x', @prev_size))}\n" unless flags.include? :prev_inuse
      ret += "data = #{Helper.color(@data.inspect)}#{'...' if @data.length < size - size_t * 2}\n"
      ret
    end

    # The chunk flags record in low three bits of size
    # @return [Array<Symbol>] flags of chunk
    # @example
    #   c = [0, 0x25].pack("Q*").to_chunk
    #   c.flags
    #   # [:non_main_arena, :prev_inuse]
    def flags
      mask = @size - size
      flag = []
      flag << :non_main_arena unless (mask & 4).zero?
      flag << :mmapped unless (mask & 2).zero?
      flag << :prev_inuse unless (mask & 1).zero?
      flag
    end

    # Ask if chunk not belongs to main arena.
    #
    # @return [Boolean] +true|false+ if chunk not belongs to main arena
    def non_main_arena?
      flags.include? :non_main_arena
    end

    # Ask if chunk is mmapped.
    #
    # @return [Boolean] +true|false+ if chunk is mmapped
    def mmapped?
      flags.include? :mmapped
    end

    # Ask if chunk has set the prev-inuse bit.
    #
    # @return [Boolean] +true|false+ if the +prev_inuse+ bit has been set
    def prev_inuse?
      flags.include? :prev_inuse
    end

    # Size of chunk
    # @return [Integer] The chunk size without flag masks
    def size
      @size & -8
    end

    # Bin type of this chunk
    # @return [Symbol] Bin type is simply determined according to +#size+
    # @example
    #   [c.size, c.size_t]
    #   #=> [80, 8]
    #   c.bintype
    #   #=> :fast
    # @example
    #   [c.size, c.size_t]
    #   #=> [80, 4]
    #   c.bintype
    #   #=> :small
    # @example
    #   c.size
    #   #=> 135168
    #   c.bintype
    #   #=> :mmap
    def bintype
      sz = size
      return :unknown if sz < @size_t * 4
      return :fast if sz <= @size_t * 16
      return :small if sz <= @size_t * 0x7e
      return :large if sz <= @size_t * 0x3ffe # is this correct?

      :mmap
    end
  end
end
