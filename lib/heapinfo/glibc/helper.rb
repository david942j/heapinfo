module HeapInfo
  module Glibc
    module Helper
      class << self
        def mem2chunk(mem)
          mem - 2 * size_t
        end

        # @return [Boolean]
        def chunk_is_mmapped(p)
          dumper.call(p, size_t * 2).to_chunk.flags.include? :mmapped
        end

        # @return [Integer]
        def ulong(n)
          n % 2 ** (size_t * 8)
        end

        # @return [HeapInfo::Arena]
        def arena_for_chunk(p)
          HeapInfo::Glibc.main_arena # not support arena other than initial main_arena
        end

        def size_t
          HeapInfo::Glibc.size_t
        end

        def dumper
          HeapInfo::Glibc.dumper
        end
      end
    end
  end
end
