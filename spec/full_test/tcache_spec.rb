# encoding: ascii-8bit
# frozen_string_literal: true

require 'heapinfo'
describe 'tcache libraries' do
  describe '64bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @hs = @tcache_libs_heapinfo.call(64)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 8
        expect(h.libc.main_arena.top_chunk.base & 0xfff).to eq 0x5a0
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7

        expect(h.libc.tcache?).to be true
      end
    end

    it 'layouts' do
      @hs.each do |h|
        expect { h.layouts(:tcache) }.to output(
          /TcacheEntry\[0x20\]:  => 0x\w+290 => 0x\w+270 => \(nil\)
TcacheEntry\[0x30\]:  => 0x\w+2b0 => 0xdeadbeef\(invalid\)
TcacheEntry\[0x40\]:  => 0x\w+2e0 => 0x\w+320 => 0x\w+2e0\(loop\)
TcacheEntry\[0x90\]:  => 0x\w+360 => \(nil\)
TcacheEntry\[0xa0\]:  => 0x\w+440 => \(nil\)/
        ).to_stdout
      end
    end
  end

  describe '32bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @hs = @tcache_libs_heapinfo.call(32)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 4
        expect(h.libc.main_arena.top_chunk.base & 0xfff).to eq 0x4a8
        expect(h.libc.main_arena.system_mem).to eq 0x22000
        expect(h.libc.main_arena.fastbin.size).to eq 7

        expect(h.libc.tcache?).to be true
      end
    end

    it 'layouts' do
      @hs.each do |h|
        expect { h.layouts(:tcache) }.to output(
          /TcacheEntry\[0x28\]:  => 0x\w+190 => 0x\w+170 => \(nil\)
TcacheEntry\[0x30\]:  => 0x\w+1b0 => 0xdeadbeef\(invalid\)
TcacheEntry\[0x38\]:  => 0x\w+1e0 => 0x\w+220 => 0x\w+1e0\(loop\)
TcacheEntry\[0x60\]:  => 0x\w+260 => \(nil\)
TcacheEntry\[0x68\]:  => 0x\w+340 => \(nil\)/
        ).to_stdout
      end
    end
  end
end
