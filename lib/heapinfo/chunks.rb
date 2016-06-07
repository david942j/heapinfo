module HeapInfo
  class Chunks
    include Enumerable
    def initialize
      @chunks = []
    end

    def <<(val)
      @chunks << val
    end

    def each(&block)
      @chunks.each(&block)
    end

    def to_s
      @chunks.map(&:to_s).join("\n")
    end

    def size
      @chunks.size
    end
    alias :length :size
  end
end
