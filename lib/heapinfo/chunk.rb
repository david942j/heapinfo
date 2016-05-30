module HeapInfo
  class Chunk
    attr_accessor :size_t, :base, :prev_size, :size, :data
    def initialize(size_t, chunk_ptr, dumper, head: false) # if fake chunk in main_arena
      fail unless [4, 8].include? size_t 
      self.class.send(:define_method, :dump){|*args| dumper.call(*args)}
      @head = head
      @size_t = size_t
      @base = chunk_ptr
      sz = dump(@base, size_t * 2)
      if head # no need to read if is bin
        @data = dump(@base + size_t * 2, size_t * 4)
        return
      end
      @prev_size = Helper.unpack(size_t, sz[0, size_t])
      @size = Helper.unpack(size_t, sz[size_t..-1])
      r_size = [@size & -8, size_t * 4].min # don't read too much data
      r_size = [r_size, 0].max # prevent negative size
      @data = dump(@base + size_t * 2, r_size)
    end
    def class_name
      self.class.name.split('::').last || self.class.name
    end
  end
end
