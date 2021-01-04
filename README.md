[![Build Status](https://travis-ci.org/david942j/heapinfo.svg?branch=master)](https://travis-ci.org/david942j/heapinfo)
[![Downloads](http://ruby-gem-downloads-badge.herokuapp.com/heapinfo?type=total)](https://rubygems.org/gems/heapinfo)
[![Code Climate](https://codeclimate.com/github/david942j/heapinfo/badges/gpa.svg)](https://codeclimate.com/github/david942j/heapinfo)
[![Issue Count](https://codeclimate.com/github/david942j/heapinfo/badges/issue_count.svg)](https://codeclimate.com/github/david942j/heapinfo)
[![Test Coverage](https://codeclimate.com/github/david942j/heapinfo/badges/coverage.svg)](https://codeclimate.com/github/david942j/heapinfo/coverage)
[![Inline docs](https://inch-ci.org/github/david942j/heapinfo.svg?branch=master)](https://inch-ci.org/github/david942j/heapinfo)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

## HeapInfo
As pwn lovers, while playing CTF with heap exploitation, we always need a debugger (e.g. gdb) for tracking memory layout. But we don't really need gdb if we want to see whether the heap layout same as our imagination or not. Hope this small tool helps us exploit easier ;).

### Why
**HeapInfo** is very helpful when binary has somehow anti-debugger limitations, e.g. being ptraced.
**HeapInfo** still works because it doesn't use ptrace.

Implements with Ruby because I love Ruby :P. But might implement with Python (if no others did) in the future.

If you prefer [pwntools](https://github.com/Gallopsled/pwntools) for exploiting, you can still use **HeapInfo** in irb/pry as a small debugger.

Any suggestion of features or bug issues is welcome.

## Install
**HeapInfo** is still under developing for more features, so the version might change frequently :p

```
$ gem install heapinfo
```

## Features
* Can use in your ruby exploit script or in irb/pry.
* **HeapInfo** works when `victim` is being traced! i.e. you can use ltrace/strace/gdb and **HeapInfo** simultaneously!
* `dump` - Dump arbitrarily address memory.
* `layouts` - Show the current bin layouts, very useful for heap exploitation.
* `offset` - Show the offset between given address and segment. Very useful for calculating relative offset.
* `canary` - Fetch the value of stack guard!
* `x` - Provide gdb-like command.
* `s` - Provide gdb-like command.
* `find` - Provide gdb-like command.
* More features and details can be found in [RDoc](http://www.rubydoc.info/github/david942j/heapinfo/master/)

## Usage

#### Load

```ruby
require 'heapinfo'
# ./victim is running
h = heapinfo('victim') 
# or use h = heapinfo(20568) to specify a pid

# will present simple info when loading:
# Program: /home/heapinfo/victim PID: 20568
# victim          base @ 0x400000
# [heap]          base @ 0x11cc000
# [stack]         base @ 0x7fff2b244000
# libc-2.19.so    base @ 0x7f892a63a000
# ld-2.19.so      base @ 0x7f892bee6000
# canary          value: 0x84b742f03d94c100

# query segments' info
"%#x" % h.libc.base
#=> "0x7f892a63a000"
h.libc.name
#=> "/lib/x86_64-linux-gnu/libc-2.19.so"
"%#x" % h.elf.base
#=> "0x400000"
"%#x" % h.heap.base
#=> "0x11cc000"
```

NOTICE: When the process is not found, most methods will return `nil`. One way to prevent some error happend is to wrapper methods within `debug`, the block will be ignored while doing remote exploitation.

```ruby
h = heapinfo('remote')
# Process not found
h.pid # nil

# wrapper with `debug` so that no error will be raised when pwning remote service
h.debug { fail unless leak_libc_base == h.libc.base }
```

#### Dump
Query content of specific address.

NOTICE: You MUST have permission of attaching a program, otherwise dump will fail.

i.e. `/proc/sys/kernel/yama/ptrace_scope` set to 0 or run as root.

```ruby
h.debug do
  p h.dump(:libc, 8)
  #=> "\x7FELF\x02\x01\x01\x00"
  p h.dump(:heap, 16)
  #=> "\x00\x00\x00\x00\x00\x00\x00\x00\x31\x00\x00\x00\x00\x00\x00\x00"
  p h.dump('heap+0x30', 16) # support offset!
  #=> "\x00\x00\x00\x00\x00\x00\x00\x00\x81\x00\x00\x00\x00\x00\x00\x00"
  p h.dump('heap+0x30 * 3 + 0x8', 16) # and even complex formula!
  #=> "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  p h.dump(:program, 8)
  #=> "\x7FELF\x02\x01\x01\x00"
  p h.dump(0x400000, 8) # or simply give address
  #=> "\x7FELF\x02\x01\x01\x00"
end

# invalid example:
# h.dump('meow') # no such segment
```

#### layouts
```ruby
h.layouts :fast
```
![fastbin layouts](https://github.com/david942j/heapinfo/blob/master/examples/fastbin_layouts.png?raw=true)

```ruby
h.layouts :unsorted, :small
```
![smallbin layouts](https://github.com/david942j/heapinfo/blob/master/examples/unsorted_smallbin_layouts.png?raw=true)

```ruby
h.layouts :tcache
```
![tcache layouts](https://github.com/david942j/heapinfo/blob/master/examples/tcache_layouts.png?raw=true)

#### offset
```ruby
h.offset(0x7fda86fe8670)
# 0xf6670 after libc
h.offset(0x1839cd0, :heap) # specific segment name
# 0x20cd0 after heap
h.offset(0x1839cd0)
# 0x20cd0 after heap
```
![offset](https://github.com/david942j/heapinfo/blob/master/examples/offset.png?raw=true)

#### canary
```ruby
h.canary.to_s(16)
#=> '84b742f03d94c100'
```

#### x - gdb-like command
```ruby
h.x 8, :heap
```
![x/8gx](https://github.com/david942j/heapinfo/blob/master/examples/x8_heap.png?raw=true)

#### find - gdb-like command
Provide a searcher of memory, easier to use than in (naive) gdb.

Support search integer, string, and even regular expression.

```ruby
h.find(0xdeadbeef, 'heap+0x10', 0x1000)
#=> 6299664 # 0x602010
h.find(/E.F/, 0x400000, 4)
#=> 4194305 # 0x400001
h.find(/E.F/, 0x400000, 3)
#=> nil

# Get relative offset of searching result
h.find('/bin/sh', :libc, rel: true)
#=> 1622391 # 0x18c177
h.offset(h.find('/bin/sh', :libc))
# 0x18c177 after libc
```

## Tests
**HeapInfo** currently only run tests on Ubuntu, followings are tested glibc versions:

* libc-2.19
* libc-2.23
* libc-2.24
* libc-2.25
* libc-2.26
* libc-2.27
* libc-2.29
