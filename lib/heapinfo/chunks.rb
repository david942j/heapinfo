module HeapInfo
  # Self-defined array for collecting chunk(s).
  class Chunks
    include Enumerable
    # Instantiate a {HeapInfo::Chunks} object.
    def initialize
      @chunks = []
    end

    # @return [void]
    def <<(val)
      @chunks << val
    end

    # @return [Integer]
    def size
      @chunks.size
    end

    # @return [void]
    def each(&block)
      @chunks.each(&block)
    end

    # Hook +#to_s+ for pretty printing.
    # @return [String]
    def to_s
      @chunks.map(&:to_s).join("\n")
    end
  end
end
