# TODO: prepare if prog not start yet
def heapinfo(prog)
  HeapInfo::Process.new(prog)
end

require 'heapinfo/process'
require 'heapinfo/helper.rb'
