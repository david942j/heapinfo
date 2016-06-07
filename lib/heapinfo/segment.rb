module HeapInfo
  class Segment
    attr_reader :base, :name
    def initialize(base, name)
      @base = base
      @name = name
    end

    def to_s
      "%-28s\tbase @ #{Helper.color("%#x" % base)}\n" % Helper.color(name.split('/')[-1])
    end

    # maps is return value of Helper.parse_maps
    def self.find(maps, name)
      need = maps.select {|m| m[3] == name}
      need = maps.select {|m| m[3].include? name} if need.empty? # be careful!
      self.new need.map{|m| m[0]}.min, name unless need.empty?
    end
  end
end
