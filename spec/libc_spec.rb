# encoding: ascii-8bit
# frozen_string_literal: true

require 'heapinfo/libc'

describe HeapInfo::Libc do
  describe 'free' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to make sure coverage
      victim = @compile_and_run.call(bit: 64, lib_ver: '2.23')
      @h = HeapInfo::Process.new(victim)
      @fake_mem = 0x13371000
      @helper = HeapInfo::Helper
      @set_memory = lambda do |str|
        @h.libc.__send__(:dumper=, lambda do |ptr, len|
          if ptr.between?(@fake_mem, @fake_mem + 0x1000)
            str[ptr - @fake_mem, len]
          else
            @h.dump(ptr, len)
          end
        end)
      end
    end

    describe 'invalid' do
      it 'invalid pointer' do
        @set_memory.call [0, 0x21, 0x21, 0x0, 0x0].pack('Q*')
        expect { @h.libc.free(@fake_mem + 24) }.to raise_error "free(): invalid pointer\n" \
                                                               "ptr(#{@helper.hex(@fake_mem + 8)}) % 16 != 0"
        expect { @h.libc.free(@fake_mem + 32) }.to raise_error "free(): invalid pointer\n" \
                                                               "ptr(#{@helper.hex(@fake_mem + 16)}) > -size(0x0)"
      end

      it 'invalid size' do
        @set_memory.call [0, 0x11].pack('Q*')
        expect { @h.libc.free(@fake_mem + 16) }.to raise_error "free(): invalid size\n" \
                                                               'size(0x10) < min_chunk_size(0x20)'
        @set_memory.call [0, 0x38].pack('Q*')
        expect { @h.libc.free(@fake_mem + 16) }.to raise_error "free(): invalid size\n" \
                                                               'alignment error: size(0x38) % 0x10 != 0'
      end
    end

    describe 'fast' do
      it 'invalid next size' do
        @set_memory.call [0, 0x21, 0, 0, 0, 0xf].pack('Q*')
        msg = "free(): invalid next size (fast)\n" \
              "next chunk(#{@helper.hex(@fake_mem + 32)}) has size(8) <=  2 * 8"
        expect { @h.libc.free(@fake_mem + 16) }.to raise_error msg
        @set_memory.call [0, 0x21, 0, 0, 0, 0x21000].pack('Q*')
        msg = "free(): invalid next size (fast)\n" \
              "next chunk(#{@helper.hex(@fake_mem + 32)}) has size(0x21000) >= av.system_mem(0x21000)"
        expect { @h.libc.free(@fake_mem + 16) }.to raise_error msg
      end

      it 'double free (fastop)' do
        expect { @h.libc.free(@h.heap.base + 0x30) }.to raise_error "double free or corruption (fasttop)\n" \
                                                                    'top of fastbin[0x20]: 0x602020=0x602020'
      end

      it 'success' do
        expect(@h.libc.free(@h.heap.base + 0x10)).to be true
      end
    end

    describe 'munmap' do
      it 'success' do
        mmap_addr = HeapInfo::Helper.unpack(8, @h.dump(':heap+0x190', 8)) # backdoor of victim.cpp
        expect(@h.libc.free(mmap_addr)).to be true
      end
    end

    describe 'small' do
      it 'success' do
        expect(@h.libc.free(@h.heap.base + 0x280)).to be true
      end
    end
  end
end
