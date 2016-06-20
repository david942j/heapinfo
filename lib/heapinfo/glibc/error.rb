module HeapInfo
  module Glibc
    # @abstract Exceptions raised by HeapInfo inherit from Error
    class Error < StandardError; end
    # Exception raised in malloc.c(malloc, free, etc.) methods.
    class MallocError < Error; end
    def malloc_assert(condition)
      raise MallocError.new(yield) unless condition
    end
  end
end
