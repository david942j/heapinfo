module HeapInfo
  class Arena
    attr_reader :fastbin, :unsorted_bin, :smallbin, :largebin, :top_chunk, :last_remainder
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
      @unsorted_bin = UnsortedBin.new(size_t, @base + 8 + size_t * 10, @dumper, head: true)
      @smallbin = Array.new(55) do |idx|
        s = Smallbin.new(size_t, @base + 8 + size_t * (26 + 2 * idx), @dumper, head: true)
        s.index = idx
        s
      end
      self
    end

    def layouts(*args)
      res = ''
      res += fastbin_layout if args.include? :fastbin
      res += unsorted_layout if args.include? :unsorted_bin
      res += smallbin_layout if args.include? :smallbin
      res
    end

    # should use inspect or to_s .. QQ?
    def fastbin_layout
      fastbin.map(&:inspect).join
    end

    def unsorted_layout
      unsorted_bin.inspect
    end

    def smallbin_layout
      smallbin.map(&:inspect).join
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

    def idx_to_size
      index * size_t * 2 + size_t * 4
    end

    def title
      "%s%s: " % [Helper.color(self.class_name, sev: :bin),  index.nil? ? nil : "[#{Helper.color("%#x" % idx_to_size)}]"]
    end

    def inspect
      ret = title
      dup = {}
      ptr = @fd
      while ptr != 0
        ret += " => %s" % Helper.color("%#x" % ptr)
        return ret += "(loop)\n" if dup[ptr]
        dup[ptr] = true
        ptr = fd_of(ptr)
        return ret += "(invalid)\n" if ptr.nil?
      end
      ret + " => (nil)\n"
    end

    def addr_of(ptr, offset)
      t = dump(ptr + size_t * offset, size_t)
      return nil if t.nil?
      Helper.unpack(size_t, t)
    end

    def fd_of(ptr)
      addr_of(ptr, 2)
    end

    def bk_of(ptr)
      addr_of(ptr, 3)
    end
  end

  class UnsortedBin < Fastbin
    attr_accessor :bk
    def initialize(*args)
      super
      @bk = Helper.unpack(size_t, @data[@size_t, @size_t])
    end

    # size: at most extend size
    # size=2: bk, bk, bin, fd, fd
    def inspect(size: 2)
      list = link_list(size)
      return '' if list.size <= 1 and self.class_name != 'UnsortedBin' # bad..
      ret = title
      center = nil
      ret += list.map.with_index do |c, idx|
        next center = Helper.color("[self]", sev: :bin) if c == @base
        fwd = fd_of(c)
        next "%s(invalid)" % Helper.color("%#x" % c) if fwd.nil? # invalid c
        bck = bk_of(c)
        if center.nil? # bk side
          next Helper.color("%s%s" % [
            Helper.color("%#x" % c),
            fwd == list[idx+1] ? nil : "(%#x)" % fwd,
          ])
        else #fd size
          next Helper.color("%s%s" % [
            bck == list[idx-1] ? nil : "(%#x)" % bck,
            Helper.color("%#x" % c),
          ])
        end
      end.join(" === ")
      ret + "\n"
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
      work.call(@fd, :fd_of, lambda{|ptr| list << ptr})
      work.call(@bk, :bk_of, lambda{|ptr| list.unshift ptr})
      list
    end
  end

  class Smallbin < UnsortedBin
    def idx_to_size
      index * size_t * 2 + size_t * 18
    end
  end

  class Largebin < Smallbin
    attr_accessor :fd_nextsize, :bk_nextsize
  end
end
