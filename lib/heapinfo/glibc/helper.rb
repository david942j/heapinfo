module HeapInfo
  module Glibc
  private
    def mem2chunk(mem)
      ulong(mem - 2 * size_t)
    end

    # @return [Boolean]
    def chunk_is_mmapped(ptr)
      # TODO: handle memory not accessible
      dumper.call(ptr, size_t * 2).to_chunk.mmapped?
    end

    def get_max_fast
      size_t * 16
    end

    # The minimal chunk size.
    # Not the real implmentation, maybe wrong some day?
    # @return [Integer] The size.
    def min_chunk_size
      size_t * 4
    end

    # Not the real implmentation, maybe wrong some day?
    # @return [Boolean]
    def aligned_ok(size)
      size & (2 * size_t - 1) == 0
    end

    # @return [Integer]
    def ulong(n)
      n % 2 ** (size_t * 8)
    end

    # @return [HeapInfo::Arena]
    def arena_for_chunk(ptr)
      # not support arena other than initial main_arena
      return if dumper.call(ptr, size_t * 2).to_chunk.non_main_arena? 
      main_arena 
    end

  end
end
