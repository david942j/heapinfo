module HeapInfo
  module Glibc
  private
    def mem2chunk(mem)
      ulong(mem - 2 * size_t)
    end

    # @return [Boolean]
    def chunk_is_mmapped(p)
      dumper.call(p, size_t * 2).to_chunk.flags.include? :mmapped
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
    def arena_for_chunk(p)
      main_arena # not support arena other than initial main_arena
    end

  end
end
