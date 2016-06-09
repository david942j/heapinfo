module HeapInfo
  module Ext
    module String
      # Methods to be mixed into String
      module InstanceMethods
        def to_chunk(bits: 64, base: 0)
          size_t = bits / 8
          dumper = lambda{|addr, len| self[addr-base, len]}
          Chunk.new(size_t, base, dumper)
        end

        def to_chunks(bits: 64, base: 0)
          size_t = bits / 8
          chunks = Chunks.new
          cur = 0
          while cur + size_t * 2 <= self.length
            now_chunk = self[cur, size_t * 2].to_chunk
            sz = now_chunk.size
            chunks << self[cur, sz + 1].to_chunk(bits: bits, base: base + cur) # +1 for dump prev_inuse
            cur += sz
          end
          chunks
        end
      end
    end
  end
end

::String.send(:include, HeapInfo::Ext::String::InstanceMethods)
