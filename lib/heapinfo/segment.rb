module HeapInfo
  # Record the base address and name in maps
  class Segment

    # Base address of segment
    attr_reader :base
    # Name of segment
    attr_reader :name
    # Instantiate a <tt>HeapInfo::Segment</tt> object
    # @param [Integer] base Base address
    # @param [String] name Name of segment
    def initialize(base, name)
      @base = base
      @name = name
    end

    # Hook <tt>#to_s</tt> for pretty printing
    # @return [String] Information of name and base address wrapper with color codes.
    def to_s
      "%-28s\tbase @ #{Helper.color("%#x" % base)}\n" % Helper.color(name.split('/')[-1])
    end

    # Helper for create an <tt>Segment</tt>
    #
    # Search the specific <tt>pattern</tt> in <tt>maps</tt> and return a <tt>HeapInfo::Segment</tt> object.
    #
    # @param [Array] maps <tt>maps</tt> is in the form of the return value of <tt>HeapInfo::Helper.parse_maps</tt>
    # @param [Regexp, String] pattern The segment name want to match in maps. If <tt>String</tt> is given, the pattern is matched as a substring.
    # @return [HeapInfo::Segment, NilClass] The request <tt>Segment</tt> object. If the pattern is not matched, <tt>nil</tt> will be returned.
    def self.find(maps, pattern)
      needs = maps.select{|m| pattern.is_a?(Regexp) ? m[3] =~ pattern : m[3].include?(pattern)}
      self.new needs.map{|m| m[0]}.min, needs[0][3] unless needs.empty?
    end
  end
end
