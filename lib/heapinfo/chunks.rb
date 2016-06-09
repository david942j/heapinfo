module HeapInfo
  # Self-defined array for collecting chunk(s)
  class Chunks
    include Enumerable
    # Instantiate a <tt>HeapInfo::Chunks</tt> object
    def initialize
      @chunks = []
    end

    # Define <tt><<</tt> method
    # @param [HeapInfo::Chunk] val chunk to be pushed
    # @return [HeapInfo::Chunks] <tt>self</tt>
    def <<(val)
      @chunks << val
      self
    end

    # To work like normal array.
    def each(&block)
      @chunks.each(&block)
    end

    # Hook <tt>#to_s</tt> for pretty printing.
    # @return [String]
    def to_s
      @chunks.map(&:to_s).join("\n")
    end

    # Number of chunks recorded.
    # @return [Integer] size
    def size
      @chunks.size
    end
    # alias <tt>length</tt> as <tt>size</tt>
    alias :length :size
  end
end
