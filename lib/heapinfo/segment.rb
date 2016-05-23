module HeapInfo
  class Segment
    attr_reader :start, :name
    def initialize(start, name)
      @start = start
      @name = name
    end

    # maps is return value of Helper.parse_maps
    def self.find(maps, name)
      Segment.new maps.select {|m| m[3] == name}.map{|m| m[0]}.min, name
    end
  end
end
