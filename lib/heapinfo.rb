# TODO: prepare if prog not start yet
# provide exact libc name (as /proc/[pid]/maps shows) can prevent auto analyze fail
# prog can also be pid (Integer)
def heapinfo(prog, libc: /libc[^\w]/)
  h = HeapInfo::Process.new(prog, libc)
  puts h
  h
end
module HeapInfo
  TMP_DIR = '/tmp/.heapinfo'
  CACHE_DIR = '~/.cache/heapinfo'
  FileUtils.mkdir_p(TMP_DIR)
  FileUtils.mkdir_p(CACHE_DIR)
end
require 'heapinfo/process'
require 'heapinfo/helper'
require 'heapinfo/segment'
require 'heapinfo/libc'
require 'heapinfo/main_arena'
require 'heapinfo/dumper'
