# Implment glibc's free-related functions
# [Reference](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html)
module HeapInfo
  module Glibc
    # Implmentation of <tt>void __libc_free(void *mem)</tt>.
    # [Source](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html#__libc_free)
    # @param [Integer] mem Memory address to be free.
    def libc_free(mem)
      # TODO: free_hook
      mem = ulong mem
      return if mem == 0 # free(0) has no effect
      ptr = mem2chunk(mem)
      return munmap_chunk(ptr) if chunk_is_mmapped(ptr)
      ar = arena_for_chunk(ptr)
      int_free(ar, ptr)
    end
    alias :free :libc_free

  private
    # Implmentation of <tt>void _int_free (mstate av, mchunkptr p, [int have_lock])</tt>.
    # [Source](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html#_int_free)
    # 
    # The original method in C is too long, split to multiple methods to match ruby convention.
    # @param [HeapInfo::Arena] av
    # @param [Integer] ptr Use <tt>ptr</tt> instead of <tt>p</tt> to prevent conflict with ruby native method.
    def int_free(av, ptr) # is have_lock important?
      chunk = dumper.call(ptr, size_t * 2).to_chunk
      size = ulong chunk.size
      invalid_pointer(ptr, size)
      invalid_size(size)
      # check_inuse_chunk # off
      if size <= get_max_fast
        int_free_fast(av, ptr)
      elsif !chunk_is_mmapped(ptr) # Though this has been checked in #libc_free
        int_free_small(av, ptr)
      else
        munmap_chunk(ptr)
      end
    end

    def int_free_fast(av, ptr)
      true
    end

    def int_free_small(av, ptr)
      true
    end

    def munmap_chunk(ptr)
      # TODO: check page alignment and... page exists? 
      true
    end

    # Start of checkers
    # TODO: Error events

    def invalid_pointer(ptr, size)
      errmsg = "free(): invalid pointer\n"
      # unsigned compare
      malloc_assert(ptr <= ulong(-size)) { errmsg + "ptr(0x%x) > -size(0x%x)" % [ptr, ulong(-size)] }
      malloc_assert(ptr % (size_t * 2) == 0) { errmsg + "ptr(0x%x) % %#x != 0" % [ptr, size_t * 2] }
    end

    def invalid_size(size)
      errmsg = "free(): invalid size\n"
      malloc_assert(size >= min_chunk_size) { errmsg + "size(0x%x) < min_chunk_size(0x%x)" % [size, min_chunk_size] }
      malloc_assert(aligned_ok size) { errmsg + "alignment error: size(0x%x) %% 0x%x != 0" % [size, size_t * 2] }
    end
  end
end
