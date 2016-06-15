module HeapInfo
  class Arena
    attr_reader :fastbin, :unsorted_bin, :smallbin, :top_chunk
    # attr_reader :largebin, :last_remainder

    # Instantiate a <tt>HeapInfo::Arena</tt> object
    #
    # @param [Integer] base Base address of arena.
    # @param [Integer] bits Either 64 or 32
    # @param [Proc] dumper For dump more data
    def initialize(base, bits, dumper)
      @base, @dumper = base, dumper
      @size_t = bits / 8
      reload!
    end

    # Refresh all attributes
    # Retrive data using <tt>@dumper</tt>, load bins, top chunk etc.
    # @return [HeapInfo::Arena] self
    def reload!
      top_ptr = Helper.unpack(size_t, @dumper.call(@base + 8 + size_t * 10, size_t))
      @fastbin = []
      return self if top_ptr == 0 # arena not init yet
      @top_chunk = Chunk.new size_t, top_ptr, @dumper
      @fastbin = Array.new(7) do |idx|
        f = Fastbin.new(size_t, @base + 8 - size_t * 2 + size_t * idx, @dumper, head: true)
        f.index = idx
        f
      end
      @unsorted_bin = UnsortedBin.new(size_t, @base + 8 + size_t * 10, @dumper, head: true)
      @smallbin = Array.new(55) do |idx|
        s = Smallbin.new(size_t, @base + 8 + size_t * (26 + 2 * idx), @dumper, head: true)
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
    #   puts h.libc.main_arena.layouts :fastbin, :unsorted_bin, :smallbin
    def layouts(*args)
      res = ''
      res += fastbin.map(&:inspect).join if args.include? :fastbin
      res += unsorted_bin.inspect if args.include? :unsorted_bin
      res += smallbin.map(&:inspect).join if args.include? :smallbin
      res
    end

  private
    attr_reader :size_t
  end

  class Fastbin < Chunk
    attr_reader :fd
    attr_accessor :index
    
    # Instantiate a <tt>HeapInfo::Fastbin</tt> object
    #
    # @param [Mixed] args See <tt>HeapInfo::Chunk</tt> for more information.
    def initialize(*args)
      super
      @fd = Helper.unpack(size_t, @data[0, @size_t])
    end

    # Mapping index of fastbin to chunk size
    # @return [Integer] size
    def idx_to_size
      index * size_t * 2 + size_t * 4
    end

    # For pretty inspect
    # @return [String] Title with color codes
    def title
      "%s%s: " % [Helper.color(Helper.class_name(self), sev: :bin),  index.nil? ? nil : "[#{Helper.color("%#x" % idx_to_size)}]"]
    end

    def inspect
      title + list.map do |ptr|
        next "(#{ptr})\n" if ptr.is_a? Symbol
        next " => (nil)\n" if ptr.nil?
        " => %s" % Helper.color("%#x" % ptr)
      end.join
    end

    # @return [Array<Integer, Symbol, NilClass>] single link list of <tt>fd</tt> chain.
    #   Last element will be:
    #   - <tt>:loop</tt> if loop detectded
    #   - <tt>:invalid</tt> invalid address detected
    #   - <tt>nil</tt> end with zero address (normal case)
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

    def fd_of(ptr)
      addr_of(ptr, 2)
    end

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

  class UnsortedBin < Fastbin
    attr_reader :bk
    def initialize(*args)
      super
      @bk = Helper.unpack(size_t, @data[@size_t, @size_t])
    end

    # size: at most extend size
    # size=2: bk, bk, bin, fd, fd
    def inspect(size: 2)
      list = link_list(size)
      return '' if list.size <= 1 and Helper.class_name(self) != 'UnsortedBin' # bad..
      title + pretty_list(list) + "\n"
    end

    def pretty_list(list)
      center = nil
      list.map.with_index do |c, idx|
        next center = Helper.color("[self]", sev: :bin) if c == @base
        fwd = fd_of(c)
        next "%s(invalid)" % Helper.color("%#x" % c) if fwd.nil? # invalid c
        bck = bk_of(c)
        if center.nil? # bk side
          next Helper.color("%s%s" % [
            Helper.color("%#x" % c),
            fwd == list[idx+1] ? nil : "(%#x)" % fwd,
          ])
        else #fd side
          next Helper.color("%s%s" % [
            bck == list[idx-1] ? nil : "(%#x)" % bck,
            Helper.color("%#x" % c),
          ])
        end
      end.join(" === ")
    end

    def link_list(expand_size)
      list = [@base]
      # fd
      work = Proc.new do |ptr, nxt, append|
        sz = 0
        dup = {}
        while ptr != @base and sz < expand_size
          append.call ptr
          break if ptr.nil? # invalid pointer
          break if dup[ptr] # looped
          dup[ptr] = true
          ptr = self.send(nxt, ptr)
          sz += 1
        end
      end
      work.call(@fd, :fd_of, ->(ptr) { list << ptr })
      work.call(@bk, :bk_of, ->(ptr) { list.unshift ptr })
      list
    end
  end

  class Smallbin < UnsortedBin

    # Mapping index of smallbin to chunk size
    # @return [Integer] size
    def idx_to_size
      index * size_t * 2 + size_t * 18
    end
  end

  # class Largebin < Smallbin
  #   attr_accessor :fd_nextsize, :bk_nextsize
  # end
end
