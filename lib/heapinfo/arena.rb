module HeapInfo
  class Arena
    attr_reader :fastbin, :unordered_bin, :small_bin, :large_bin, :top_chunk, :last_remainder
    def initialize(base, arch, dumper)
      @base, @arch, @dumper = base, arch, dumper
      reload
    end

    def reload
      top_ptr = Helper.unpack(size_t, @dumper.call(@base + 8 + size_t * 10, size_t))
      @fastbin = []
      return self if top_ptr == 0 # arena not init yet
      @top_chunk = Chunk.new size_t, top_ptr, @dumper
      @fastbin = Array.new(7) do |idx|
        f = Fastbin.new(size_t, @base + 8 - size_t * 2 + size_t * idx, @dumper, head: true)
        f.index = idx
        f
      end
      self 
    end

    def layout(*args)
      res = ''
      res += fastbin_layout if args.include? :fastbin
      res
    end

    # should use inspect or to_s .. QQ?
    def fastbin_layout
      fastbin.map(&:inspect).join "\n"
    end

  private
    def size_t
      @arch == '32' ? 4 : 8
    end
  end

  class Fastbin < Chunk
    attr_accessor :fd, :index
    def initialize(*args)
      super
      @fd = Helper.unpack(size_t, @data[0, @size_t])
    end

    def inspect
      ret = "%s[%s]" % [Helper.color("Fastbin", sev: :bin),  Helper.color(index)]
      ptr = @fd
      while ptr != 0
        # TODO: handle invalid ptr # important!
        ret += " => %s" % Helper.color("%#x" % ptr)
        t = dump(ptr + size_t * 2, size_t)
        return ret += " => (invalid)" if t.nil?
        ptr = Helper.unpack(size_t, t)
      end
      ret + " => (nil)"
    end
  end

  class Smallbin < Fastbin
    attr_accessor :bk
    def initialize(*args)
      super
      @bk = Helper.unpack(size_t, @data[@size_t, @size_t])
    end
  end

  class Largebin < Smallbin
    attr_accessor :fd_nextsize, :bk_nextsize
  end
end
