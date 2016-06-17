module HeapInfo
  module Glibc
    class << self
      attr_accessor :size_t
      attr_accessor :dumper
      attr_accessor :main_arena
      def size_t
        @size_t || 8
      end
    end
  end
end
require 'heapinfo/glibc/helper.rb'
require 'heapinfo/glibc/free.rb'
