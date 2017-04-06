module HeapInfo
  # Implement free-related functions.
  module Glibc
    # Implmentation of +void __libc_free(void *mem)+.
    #
    # Reference:
    # {https://github.com/david942j/heapinfo/blob/master/examples/libcdb/libc-2.23/malloc.c#L2934 glibc-2.23}
    # and {https://code.woboq.org/userspace/glibc/malloc/malloc.c.html#__libc_free Online Source}
    # @param [Integer] mem Memory address to be free.
    def libc_free(mem)
      # TODO: free_hook
      mem = ulong mem
      return if mem.zero? # free(0) has no effect
      ptr = mem2chunk(mem)
      return munmap_chunk(ptr) if chunk_is_mmapped(ptr)
      av = arena_for_chunk(ptr)
      int_free(av, ptr)
    end
    alias free libc_free

    private

    # Implmentation of <tt>void _int_free (mstate av, mchunkptr p, [int have_lock])</tt>.
    #
    # The original method in C is too long, split to multiple methods to match ruby convention.
    # @param [HeapInfo::Arena] av
    # @param [Integer] ptr Use <tt>ptr</tt> instead of <tt>p</tt> to prevent confusing with ruby native method.
    def int_free(av, ptr) # is have_lock important?
      chunk = dumper.call(ptr, size_t * 2).to_chunk
      size = ulong chunk.size
      invalid_pointer(ptr, size)
      invalid_size(size)
      # check_inuse_chunk # off
      if size <= get_max_fast
        int_free_fast(av, ptr, size)
      elsif !chunk_is_mmapped(ptr) # Though this has been checked in #libc_free
        int_free_small(av, ptr, size)
        # else # never reached block, redundant code in glibc.
        # munmap_chunk(ptr)
      end
    end

    def int_free_fast(av, ptr, size)
      invalid_next_size(:fast, av, ptr, size)
      idx = fastbin_index(size)
      old = av.fastbin[idx].fd
      malloc_assert(old != ptr) do
        format("double free or corruption (fasttop)\ntop of fastbin[0x%x]: 0x%x=0x%x", size & -8, ptr, ptr)
      end
      true
    end

    def int_free_small(av, ptr, size) # rubocop:disable UnusedMethodArgument
      # TODO: unfinished
      true
    end

    def munmap_chunk(ptr) # rubocop:disable UnusedMethodArgument
      # TODO: check page alignment and... page exists?
      true
    end

    # Start of checkers

    def invalid_pointer(ptr, size)
      errmsg = "free(): invalid pointer\n"
      # unsigned compare
      malloc_assert(ptr <= ulong(-size)) { errmsg + format('ptr(0x%x) > -size(0x%x)', ptr, ulong(-size)) }
      malloc_assert((ptr % (size_t * 2)).zero?) { errmsg + format('ptr(0x%x) %% %d != 0', ptr, size_t * 2) }
    end

    def invalid_size(size)
      errmsg = "free(): invalid size\n"
      malloc_assert(size >= min_chunk_size) do
        errmsg + format('size(0x%x) < min_chunk_size(0x%x)', size, min_chunk_size)
      end
      malloc_assert(aligned_ok(size)) { errmsg + format('alignment error: size(0x%x) %% 0x%x != 0', size, size_t * 2) }
    end

    def invalid_next_size(type, av, ptr, size)
      errmsg = "free(): invalid next size (#{type})\n"
      nxt_chk = dumper.call(ptr + size, size_t * 2).to_chunk(base: ptr + size)
      malloc_assert(nxt_chk.size > 2 * size_t) do
        errmsg + format("next chunk(0x%x) has size(#{nxt_chk.size}) <=  2 * #{size_t}", nxt_chk.base)
      end
      malloc_assert(nxt_chk.size < av.system_mem) do
        errmsg + format('next chunk(0x%x) has size(0x%x) >= av.system_mem(0x%x)',
                        nxt_chk.base, nxt_chk.size, av.system_mem)
      end
    end
  end
end
