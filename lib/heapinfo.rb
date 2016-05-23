# TODO: prepare if prog not start yet
# provide exact libc name (as /proc/[pid]/maps shows) can prevent auto analyze fail
# prog can also be pid (Integer)
def heapinfo(prog, libc: /libc[^\w]/)
  h = HeapInfo::Process.new(prog, libc)
  puts h
  h
end

require 'heapinfo/process'
require 'heapinfo/helper'
require 'heapinfo/segment'
require 'heapinfo/dumper'
