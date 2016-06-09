module HeapInfo
  # The object of a heap chunk
  class Chunk
    # @return [Integer] 4 or 8 according to 32bit or 64bit, respectively.
    attr_accessor :size_t
    attr_accessor :base, :prev_size, :size, :data

    # Instantiate a <tt>HeapInfo::Chunk</tt> object
    #
    # @param [Integer] size_t 4 or 8
    # @param [Integer] base Start address of this chunk
    # @param [Proc] dumper For dump more information of this chunk
    def initialize(size_t, base, dumper, head: false) # head: if fake chunk in main_arena
      fail unless [4, 8].include? size_t 
      self.class.send(:define_method, :dump){|*args| dumper.call(*args)}
      @size_t = size_t
      @base = base
      sz = dump(@base, size_t * 2)
      if head # no need to read size if is bin
        return @data = dump(@base + size_t * 2, size_t * 4)
      end
      @prev_size = Helper.unpack(size_t, sz[0, size_t])
      @size = Helper.unpack(size_t, sz[size_t..-1])
      r_size = [real_size - size_t * 2, size_t * 4].min # don't read too much data
      r_size = [r_size, 0].max # prevent negative size
      @data = dump(@base + size_t * 2, r_size)
    end
    def to_s
      ret = Helper.color("#<%s:%#x>\n" % [self.class.to_s, @base], sev: :klass) +
      "flags = [#{flags.map{|f|Helper.color(":#{f}", sev: :sym)}.join(',')}]\n" +
      "size = #{Helper.color "%#x" % real_size} (#{bintype})\n"
      ret += "prev_size = #{Helper.color "%#x" % @prev_size}\n" unless flags.include? :prev_inuse
      ret += "data = #{Helper.color @data.inspect}#{'...' if @data.length < real_size - size_t * 2}\n"
      ret
    end

    def flags
      mask = @size - real_size
      flag = []
      flag << :non_main_arena unless mask & 4 == 0
      flag << :mmapped unless mask & 2 == 0
      flag << :prev_inuse unless mask & 1 == 0
      flag
    end

    def real_size
      @size & -8
    end

    def bintype
      sz = real_size
      return '????' if sz < @size_t * 4
      return 'fast' if sz <= @size_t * 16
      return 'small' if sz <= @size_t * 0x7e
      return 'large' if sz <= @size_t * 0x3ffe # is this correct? 
      return 'mmap'
    end

    def class_name
      self.class.name.split('::').last || self.class.name
    end
  end
end
