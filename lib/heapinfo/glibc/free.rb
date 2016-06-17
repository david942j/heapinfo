module HeapInfo
  module Glibc
    # Implment glibc's free-related functions
    # [Reference](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html)
    module Free
      class << self
        # Implmentation of <tt>void __libc_free(void *mem)</tt>.
        # [Source](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html#__libc_free)
        # @param [Integer] mem Memory address to be free.
        def libc_free(mem)
          # TODO: free_hook
          return if mem == 0 # free(0) has no effect
          p = HeapInfo::Glibc::Helper.mem2chunk(mem)
          if HeapInfo::Glibc::Helper.chunk_is_mmapped(p)
            # check page alignment and... page exists? 
            return
          end
          ar = HeapInfo::Glibc::Helper::arena_for_chunk(p)
          int_free(ar, p)
        end

        # Implmentation of <tt>void _int_free (mstate av, mchunkptr p, [int have_lock])</tt>.
        # [Source](https://code.woboq.org/userspace/glibc/malloc/malloc.c.html#_int_free)
        # 
        # The original method in C is too long, split to multiple methods to match ruby convention.
        # @param [HeapInfo::Arena] av
        # @param [Integer] ptr Use <tt>ptr</tt> instead of <tt>p</tt> to prevent conflict with ruby native method.
        def int_free(av, ptr) # is have_lock important?
          chunk = dumper.call(ptr, size_t * 2).to_chunk
          size = chunk.size
          return if invalid_pointer(ptr, size)
        end

        # Start of checkers
        # TODO: Error events

        def invalid_pointer(ptr, size)
          # unsigned compare
          return true if HeapInfo::Glibc::Helper.ulong(ptr) > HeapInfo::Glibc::Helper.ulong(-size)
          return true if ptr % (size_t * 2) != 0
          false
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
