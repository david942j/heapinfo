require 'heapinfo/chunk'
require 'heapinfo/chunks'

module HeapInfo
  # Define extensions of naive objects.
  module Ext
    # Extension of +String+ class.
    module String
      # Methods to be mixed into String
      module InstanceMethods
        # Convert string to a {HeapInfo::Chunk}.
        # @option [Integer] bits 32 or 64 bit of this chunk.
        # @option [Integer] base Base address will show when print the {Chunk} object.
        # @return [HeapInfo::Chunk]
        def to_chunk(bits: 64, base: 0)
          size_t = bits / 8
          dumper = ->(addr, len) { self[addr - base, len] }
          Chunk.new(size_t, base, dumper)
        end

        # Convert string to array of {HeapInfo::Chunk}.
        # @option [Integer] bits 32 or 64 bit of this chunk.
        # @option [Integer] base Base address will show when print the {Chunk} object.
        # @return [HeapInfo::Chunks]
        def to_chunks(bits: 64, base: 0)
          size_t = bits / 8
          chunks = Chunks.new
          cur = 0
          while cur + size_t * 2 <= length
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

::String.__send__(:include, HeapInfo::Ext::String::InstanceMethods)
