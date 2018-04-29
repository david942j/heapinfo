# encoding: ascii-8bit

require 'heapinfo'
describe 'tcache libraries' do
  describe '64bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to make sure coverage
      @hs = @tcache_libs_heapinfo.call(64)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 8
        expect(h.libc.main_arena.top_chunk.base).to eq 0x6225a0
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7
      end
    end
  end

  describe '32bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to make sure coverage
      @hs = @tcache_libs_heapinfo.call(32)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 4
        expect(h.libc.main_arena.top_chunk.base).to eq 0x806b4a8
        expect(h.libc.main_arena.system_mem).to eq 0x22000
        expect(h.libc.main_arena.fastbin.size).to eq 7
      end
    end
  end
end
