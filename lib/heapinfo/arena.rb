require 'heapinfo/chunk'
require 'heapinfo/helper'

module HeapInfo
  # Records status of an arena, including bin(s) and top chunk.
  class Arena
    # @return [Array<HeapInfo::Fastbin>] Fastbins in an array.
    attr_reader :fastbin
    # @return [HeapInfo::Chunk] Current top chunk.
    attr_reader :top_chunk
    # @return [HeapInfo::Chunk] Current last remainder.
    attr_reader :last_remainder
    # @return [Array<HeapInfo::UnsortedBin>] The unsorted bin (array size will always be one).
    attr_reader :unsorted_bin
    # @return [Array<HeapInfo::Smallbin>] Smallbins in an array.
    attr_reader :smallbin
    # @return [Integer] The +system_mem+ in arena.
    attr_reader :system_mem
    # attr_reader :largebin

    # Instantiate a {HeapInfo::Arena} object.
    #
    # @param [Integer] base Base address of arena.
    # @param [Integer] size_t Either 8 or 4
    # @param [Proc] dumper For dump more data
    def initialize(base, size_t, dumper)
      @base = base
      @size_t = size_t
      @dumper = dumper
      reload!
    end

    # Refresh all attributes.
    # Retrive data using +@dumper+, load bins, top chunk etc.
    # @return [HeapInfo::Arena] self
    def reload!
      top_ptr_offset = @base + 8 + size_t * 10
      top_ptr = Helper.unpack(size_t, @dumper.call(top_ptr_offset, size_t))
      @fastbin = []
      return self if top_ptr.zero? # arena not init yet
      @top_chunk = Chunk.new size_t, top_ptr, @dumper
      @last_remainder = Chunk.new size_t, top_ptr_offset + 8, @dumper
      # this offset diff after 2.23
      @system_mem = Array.new(2) do |off|
        Helper.unpack(size_t, @dumper.call(top_ptr_offset + 258 * size_t + 16 + off * size_t, size_t))
      end.find { |val| val >= 0x21000 && (val & 0xfff).zero? }
      @fastbin = Array.new(7) do |idx|
        f = Fastbin.new(size_t, @base + 8 - size_t * 2 + size_t * idx, @dumper, head: true)
        f.index = idx
        f
      end
      @unsorted_bin = UnsortedBin.new(size_t, top_ptr_offset, @dumper, head: true)
      @smallbin = Array.new(62) do |idx|
        s = Smallbin.new(size_t, @base + 8 + size_t * (12 + 2 * idx), @dumper, head: true)
        s.index = idx
        s
      end
      self
    end

    # Pretty dump of bins layouts.
    #
    # @param [Symbol] args Bin type(s) you want to see.
    # @return [String] Bin layouts that wrapper with color codes.
    # @example
    #   puts h.libc.main_arena.layouts(:fast, :unsorted, :small)
    #   puts h.libc.main_arena.layouts(:all)
    def layouts(*args)
      args.concat(%i[fast unsort small large]) if args.map(&:to_s).include?('all')
      args = args.map(&:to_s).join('|')
      res = ''
      res += fastbin.map(&:inspect).join if args.include?('fast')
      res += unsorted_bin.inspect if args.include?('unsort')
      res += smallbin.map(&:inspect).join if args.include?('small')
      res
    end

    private

    attr_reader :size_t
  end

  # Class for record fastbin type chunk.
  class Fastbin < Chunk
    # @return [Integer] fd
    attr_reader :fd
    # @return [Integer] index
    attr_accessor :index

    # Instantiate a {HeapInfo::Fastbin} object.
    #
    # @param [Mixed] args See {HeapInfo::Chunk} for more information.
    def initialize(*args)
      super
      @fd = Helper.unpack(size_t, @data[0, @size_t])
    end

    # Mapping index of fastbin to chunk size.
    # @return [Integer] size
    def idx_to_size
      index * size_t * 2 + size_t * 4
    end

    # For pretty inspect.
    # @return [String] Title with color codes.
    def title
      class_name = Helper.color(Helper.class_name(self), sev: :bin)
      size_str = index.nil? ? nil : "[#{Helper.color(format('%#x', idx_to_size))}]"
      "#{class_name}#{size_str}: "
    end

    # Pretty inspect.
    # @return [String] fastbin layouts wrapper with color codes.
    def inspect
      title + list.map do |ptr|
        next "(#{ptr})\n" if ptr.is_a?(Symbol)
        next " => (nil)\n" if ptr.nil?
        format(' => %s', Helper.color(format('%#x', ptr)))
      end.join
    end

    # @return [Array<Integer, Symbol, nil>] single link list of +fd+ chain.
    #   Last element will be:
    #   - +:loop+ if loop detectded
    #   - +:invalid+ invalid address detected
    #   - +nil+ end with zero address (normal case)
    def list
      dup = {}
      ptr = @fd
      ret = []
      while ptr != 0
        ret << ptr
        return ret << :loop if dup[ptr]
        dup[ptr] = true
        ptr = fd_of(ptr)
        return ret << :invalid if ptr.nil?
      end
      ret << nil
    end

    # @param [Integer] ptr Get the +fd+ value of chunk at +ptr+.
    # @return [Integer] The +fd+.
    def fd_of(ptr)
      addr_of(ptr, 2)
    end

    # @param [Integer] ptr Get the +bk+ value of chunk at +ptr+.
    # @return [Integer] The +bk+.
    def bk_of(ptr)
      addr_of(ptr, 3)
    end

    private

    def addr_of(ptr, offset)
      t = dump(ptr + size_t * offset, size_t)
      return nil if t.nil?
      Helper.unpack(size_t, t)
    end
  end

  # Class for record unsorted bin type chunk.
  class UnsortedBin < Fastbin
    # @return [Integer]
    attr_reader :bk

    # Instantiate a {HeapInfo::UnsortedBin} object.
    #
    # @param [Mixed] args See {HeapInfo::Chunk} for more information.
    def initialize(*args)
      super
      @bk = Helper.unpack(size_t, @data[@size_t, @size_t])
    end

    # @param [Integer] size
    #   At most expand size. For +size = 2+, the expand list would be <tt>bk, bk, bin, fd, fd</tt>.
    # @return [String] Unsorted bin layouts wrapper with color codes.
    def inspect(size: 2)
      list = link_list(size)
      return '' if list.size <= 1 && Helper.class_name(self) != 'UnsortedBin' # bad..
      title + pretty_list(list) + "\n"
    end

    # Wrapper the doubly linked list with color codes.
    # @param [Array<Integer>] list The list from {#link_list}.
    # @return [String] Wrapper with color codes.
    def pretty_list(list)
      center = nil
      list.map.with_index do |c, idx|
        next center = Helper.color('[self]', sev: :bin) if c == @base
        color_c = Helper.color(format('%#x', c))
        fwd = fd_of(c)
        next "#{color_c}(invalid)" if fwd.nil? # invalid c
        bck = bk_of(c)
        if center.nil? # bk side
          format('%s%s', color_c, fwd == list[idx + 1] ? nil : Helper.color(format('(%#x)', fwd)))
        else # fd side
          format('%s%s', bck == list[idx - 1] ? nil : Helper.color(format('(%#x)', bck)), color_c)
        end
      end.join(' === ')
    end

    # Return the double link list with bin in the center.
    #
    # The list will like +[..., bk of bk, bk of bin, bin, fd of bin, fd of fd, ...]+.
    # @param [Integer] expand_size
    #   At most expand size. For +size = 2+, the expand list would be <tt>bk, bk, bin, fd, fd</tt>.
    # @return [Array<Integer>] The linked list.
    def link_list(expand_size)
      list = [@base]
      # fd
      work = proc do |ptr, nxt, append|
        sz = 0
        dup = {}
        while ptr != @base && sz < expand_size
          append.call(ptr)
          break if ptr.nil? || dup[ptr] # invalid or duplicated pointer
          dup[ptr] = true
          ptr = __send__(nxt, ptr)
          sz += 1
        end
      end
      work.call(@fd, :fd_of, ->(ptr) { list << ptr })
      work.call(@bk, :bk_of, ->(ptr) { list.unshift(ptr) })
      list
    end
  end

  # Class for record smallbin type chunk.
  class Smallbin < UnsortedBin
    # Mapping index of smallbin to chunk size.
    # @return [Integer] size
    def idx_to_size
      index * size_t * 2 + size_t * 4
    end
  end

  # class Largebin < Smallbin
  #   attr_accessor :fd_nextsize, :bk_nextsize
  # end
end
