module HeapInfo
  module Glibc
    attr_accessor :size_t
  private
    attr_accessor :main_arena
    attr_accessor :dumper
  end
end
require 'heapinfo/glibc/helper.rb'
require 'heapinfo/glibc/free.rb'
