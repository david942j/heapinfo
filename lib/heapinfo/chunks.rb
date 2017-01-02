module HeapInfo
  # Self-defined array for collecting chunk(s)
  class Chunks
    # Instantiate a <tt>HeapInfo::Chunks</tt> object
    def initialize
      @chunks = []
    end

    def method_missing(method_sym, *arguments, &block) # :nodoc:
      return super unless @chunks.respond_to? method_sym
      @chunks.send(method_sym, *arguments, &block)
    end

    # Hook <tt>#to_s</tt> for pretty printing.
    # @return [String]
    def to_s
      @chunks.map(&:to_s).join("\n")
    end
  end
end
