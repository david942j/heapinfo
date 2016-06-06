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
  end
end
