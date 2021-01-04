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
        expect(h.libc.main_arena.top_chunk.base).to eq 0x6225a0
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7

        expect(h.libc.tcache?).to be true
      end
    end

    it 'layouts' do
      @hs.each do |h|
        expect { h.layouts(:tcache) }.to output(<<-EOS).to_stdout
TcacheEntry[0x20]:  => 0x622290 => 0x622270 => (nil)
TcacheEntry[0x30]:  => 0x6222b0 => 0xdeadbeef(invalid)
TcacheEntry[0x40]:  => 0x6222e0 => 0x622320 => 0x6222e0(loop)
TcacheEntry[0x90]:  => 0x622360 => (nil)
TcacheEntry[0xa0]:  => 0x622440 => (nil)
        EOS
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
        expect(h.libc.main_arena.top_chunk.base).to eq 0x806b4a8
        expect(h.libc.main_arena.system_mem).to eq 0x22000
        expect(h.libc.main_arena.fastbin.size).to eq 7

        expect(h.libc.tcache?).to be true
      end
    end

    it 'layouts' do
      @hs.each do |h|
        expect { h.layouts(:tcache) }.to output(<<-EOS).to_stdout
TcacheEntry[0x28]:  => 0x806b190 => 0x806b170 => (nil)
TcacheEntry[0x30]:  => 0x806b1b0 => 0xdeadbeef(invalid)
TcacheEntry[0x38]:  => 0x806b1e0 => 0x806b220 => 0x806b1e0(loop)
TcacheEntry[0x60]:  => 0x806b260 => (nil)
TcacheEntry[0x68]:  => 0x806b340 => (nil)
        EOS
      end
    end
  end
end
