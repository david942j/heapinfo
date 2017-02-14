module HeapInfo
  # To define heap-related functions in glibc.
  module Glibc
    attr_accessor :size_t

    private

    attr_accessor :main_arena
    attr_accessor :dumper
  end
end

require 'heapinfo/glibc/error.rb'
require 'heapinfo/glibc/helper.rb'
require 'heapinfo/glibc/free.rb'
