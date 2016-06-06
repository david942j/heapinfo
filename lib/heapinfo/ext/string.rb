module HeapInfo
  module Ext
    module String
      # Methods to be mixed into String
      module InstanceMethods
        def to_chunk(bits: 64)
          size_t = bits / 8
          dumper = lambda{|addr, len| self[addr, len]}
          Chunk.new(size_t, 0, dumper)
        end

        def to_chunks(bits: 64)
          size_t = bits / 8
          chunks = Chunks.new
          cur = 0
          while cur + size_t * 2 < self.length
            now_chunk = self[cur, size_t * 2].to_chunk
            sz = now_chunk.size & -8
            chunks << self[cur, sz].to_chunk
            cur += sz
          end
          chunks
        end
      end
    end
  end
end

::String.send(:include, HeapInfo::Ext::String::InstanceMethods)
