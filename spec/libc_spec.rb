# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Libc do
  describe 'free' do
    before(:all) do
      HeapInfo::Cache.send :clear_all # force cache miss, to make sure coverage
      @victim = HeapInfo::TMP_DIR + '/victim'
      %x(g++ #{File.expand_path('../files/victim.cpp', __FILE__)} -o #{@victim} 2>&1 > /dev/null)
      pid = fork
      # run without ASLR
      exec "setarch `uname -m` -R /bin/sh -c #{@victim}" if pid.nil?
      loop until `pidof #{@victim}` != '' 
      @h = HeapInfo::Process.new(@victim, ld: '/ld')
      @fake_mem = 0x13371000
      @set_memory = ->(str) do
        @h.libc.send(:dumper=, ->(ptr, len){
          if ptr.between?(@fake_mem, @fake_mem + 0x1000)
            str[ptr - @fake_mem, len]
          else
            @h.dump(ptr, len)
          end
        })
      end
    end
    after(:all) do
      `killall #{@victim}`
      FileUtils.rm(@victim)
    end

    describe 'invalid' do
      it 'invalid pointer' do
        @set_memory.call [0, 0x21, 0x21, 0x0, 0x0].pack("Q*")
        expect {@h.libc.free(@fake_mem + 24)}.to raise_error "free(): invalid pointer\nptr(#{HeapInfo::Helper.hex(@fake_mem + 8)}) % 16 != 0"
        expect {@h.libc.free(@fake_mem + 32)}.to raise_error "free(): invalid pointer\nptr(#{HeapInfo::Helper.hex(@fake_mem + 16)}) > -size(0x0)"
      end

      it 'invalid size' do
        @set_memory.call [0, 0x11].pack("Q*")
        expect {@h.libc.free(@fake_mem + 16)}.to raise_error "free(): invalid size\nsize(0x10) < min_chunk_size(0x20)"
        @set_memory.call [0, 0x38].pack("Q*")
        expect {@h.libc.free(@fake_mem + 16)}.to raise_error "free(): invalid size\nalignment error: size(0x38) % 0x10 != 0"
      end
    end

    describe 'fast' do
      it 'invalid next size' do
        @set_memory.call [0, 0x21, 0, 0, 0, 0xf].pack("Q*")
        expect {@h.libc.free(@fake_mem + 16)}.to raise_error "free(): invalid next size (fast)\nnext chunk(#{HeapInfo::Helper.hex(@fake_mem + 32)}) has size(8) <=  2 * 8"
        @set_memory.call [0, 0x21, 0, 0, 0, 0x21000].pack("Q*")
        expect {@h.libc.free(@fake_mem + 16)}.to raise_error "free(): invalid next size (fast)\nnext chunk(#{HeapInfo::Helper.hex(@fake_mem + 32)}) has size(0x21000) >= av.system_mem(0x21000)"
      end

      it 'double free (fastop)' do
        expect { @h.libc.free(@h.heap.base + 0x30) }.to raise_error "double free or corruption (fasttop)\ntop of fastbin[0x20]: 0x602020=0x602020"
      end
    end
  end
end
