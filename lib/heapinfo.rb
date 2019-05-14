# frozen_string_literal: true

# Basic requirements from standard library
require 'fileutils'

require 'heapinfo/ext/string.rb'
require 'heapinfo/process'

# HeapInfo - an interactive debugger for heap exploitation
#
# HeapInfo makes pwning life easier with ruby style memory dumper.
# Easy to show bin(s) layouts, or dump memory for checking whether exploit (will) works.
# HeapInfo can be used with ltrace/strace/gdb simultaneously since it not use any ptrace.
#
# @author david942j
module HeapInfo
  # Directory for writing some tmp files when working,
  # make sure /tmp is writable
  TMP_DIR = '/tmp/.heapinfo'
  FileUtils.mkdir_p(TMP_DIR)

  # Entry point for using {HeapInfo}.
  # Show segments info of the process after loaded.
  # @param [String, Integer] prog
  #   The program name of victim. If a number is given, seem as pid (useful when multi-processes exist).
  # @param [Hash] options Give library's file name.
  # @option options [String, Regexp] :libc file name of glibc, default is +/bc[^a-z]*\.so/+.
  # @return [HeapInfo::Process] The object for further usage.
  # @example
  #   h = heapinfo './victim'
  #   # outputs:
  #   # Program: /home/heapinfo/victim PID: 20568
  #   # victim          base @ 0x400000
  #   # [heap]          base @ 0x11cc000
  #   # [stack]         base @ 0x7fff2b244000
  #   # libc-2.19.so    base @ 0x7f892a63a000
  #   # ld-2.19.so      base @ 0x7f892bee6000
  #   # canary          value: 0x84b742f03d94c100
  #   p h.libc.name
  #   #=> "/lib/x86_64-linux-gnu/libc-2.19.so"
  #   p h.ld.name
  #   #=> "/lib/x86_64-linux-gnu/ld-2.19.so"
  #   p h.heap.base.to_s(16)
  #   #=> '11cc000'
  #
  # @example
  #   h = heapinfo(27605, libc: 'libc.so.6')
  #   # pid 27605 is run by custom loader
  #   p h.libc.name
  #   #=> "/home/heapinfo/libc.so.6"
  #   p h.ld.name
  #   #=> "/home/heapinfo/ld-linux-x86-64.so.2"
  def self.heapinfo(prog, options = {})
    HeapInfo::Process.new(prog, options).tap { |h| $stdout.puts h }
  end
end

# Alias method of #HeapInfo::heapinfo for global usage
# @return [HeapInfo::Process]
# @param [Mixed] args see #HeapInfo::heapinfo for more information
def heapinfo(*args)
  ::HeapInfo.heapinfo(*args)
end
