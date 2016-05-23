# TODO: prepare if prog not start yet
# provide exact libc name (as /proc/[pid]/maps shows) can prevent auto analyze fail
def heapinfo(prog, libc: 'libc')
  HeapInfo::Process.new(prog, libc)
end

require 'heapinfo/process'
require 'heapinfo/helper.rb'
