module HeapInfo
  class Arena
    attr_reader :fastbin, :unordered_bin, :small_bin, :large_bin, :top_chunk
    def initialize(base, arch, dumper)
      @base, @arch, @dumper = base, arch, dumper
      reload
    end

    def reload
      @fastbin = Array.new(7){|idx| Fastbin.new(size_t, @base + 8 - size_t * 2 + size_t * idx, @dumper, head: true)}
      self 
    end

  private
    def size_t
      @arch == '32' ? 4 : 8
    end
  end

  class Fastbin < Chunk
    attr_accessor :fd
    def initialize(*args)
      super
      @fd = Helper.unpack(size_t, @data[0, @size_t])
    end
  end

  class Smallbin < Chunk
    attr_accessor :bk
  end

  class Largebin < Smallbin
    attr_accessor :fd_nextsize, :bk_nextsize
  end
end
