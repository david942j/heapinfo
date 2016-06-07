[![Code Climate](https://codeclimate.com/github/david942j/heapinfo/badges/gpa.svg)](https://codeclimate.com/github/david942j/heapinfo)
[![Issue Count](https://codeclimate.com/github/david942j/heapinfo/badges/issue_count.svg)](https://codeclimate.com/github/david942j/heapinfo)
[![Test Coverage](https://codeclimate.com/github/david942j/heapinfo/badges/coverage.svg)](https://codeclimate.com/github/david942j/heapinfo/coverage)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

## HeapInfo
While playing CTF with heap exploitation, we always need a debugger (e.g. gdb) for tracking memory layout. But we don't really need a debugger if we just want to see whether the heap layout same as our imagine or not. Hope this small tool helps us exploit easier ;).

Implement with ruby because I love ruby :P. But might also implement with Python (if no others did) in the future.

There's almost NOTHING here now. Will implement a pretty dump of heap / bin layout first, any suggestion of features is welcome.

Relation works are [pwntools-ruby](https://github.com/peter50216/pwntools-ruby) and [gdbpwn](https://github.com/scwuaptx/Pwngdb).

## Usage

#### Load
```ruby
require 'heapinfo'
# ./victim is running
h = heapinfo('victim') 
# or use h = heapinfo(20568) to prevent multi processes exist

# will present simple info when loading:
# Program: /home/ubuntu/victim PID: 20568
# victim          base @ 0x400000
# heap            base @ 0x11cc000
# stack           base @ 0x7fffa0e20000
# libc-2.19.so    base @ 0x7f62b146b000

# query segments' info
"%#x" % h.libc.base
# => "0x7f62b146b000"
h.libc.name
# => "/lib/x86_64-linux-gnu/libc-2.19.so"
"%#x" % h.elf.base
# => "0x400000"
"%#x" % h.heap.base
# => "0x11cc000"
```

#### Dump
query content of specific address   
NOTICE: you MUST have permission of attaching a program, otherwise dump will fail   
i.e. `/proc/sys/kernel/yama/ptrace_scope` set to 0 or run as root

```ruby
p h.dump(:libc, 8)
# => "\x7FELF\x02\x01\x01\x00"
p h.dump(:heap, 16)
# => "\x00\x00\x00\x00\x00\x00\x00\x00\x31\x00\x00\x00\x00\x00\x00\x00"
p h.dump('heap+0x30, 16') # support offset!
# => "\x00\x00\x00\x00\x00\x00\x00\x00\x81\x00\x00\x00\x00\x00\x00\x00"
p h.dump(0x400000, 8) # or simply give addr
# => "\x7FELF\x02\x01\x01\x00"

# invalid examples:
# h.dump('meow') # no such segment
# h.dump('heap-1, 64') # not support `-`
# h.dump('heap+123, 256, 64') # valid but parser will take it same as 'heap+123, 64'
```
