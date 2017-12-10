# encoding: ascii-8bit

require 'heapinfo'
describe "Bin's operation" do
  describe '64bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to make sure coverage
      @hs = @all_libs_heapinfo.call(64)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 8
        expect(h.libc.main_arena.top_chunk.base).to eq 0x602340
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7
      end
    end

    describe 'fastbin' do
      it 'normal' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[0].list).to eq [0x602020, 0x602000, nil]
        end
      end

      it 'invalid' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[1].list).to eq [0x602040, 0xdeadbeef, :invalid]
        end
      end

      it 'loop' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[2].list).to eq [0x602070, 0x6020b0, 0x602070, :loop]
        end
      end

      it 'fastbin' do
        @hs.each do |h|
          expect { h.layouts(:fastbin) }.to output(<<-'EOS').to_stdout
Fastbin[0x20]:  => 0x602020 => 0x602000 => (nil)
Fastbin[0x30]:  => 0x602040 => 0xdeadbeef(invalid)
Fastbin[0x40]:  => 0x602070 => 0x6020b0 => 0x602070(loop)
Fastbin[0x50]:  => (nil)
Fastbin[0x60]:  => (nil)
Fastbin[0x70]:  => (nil)
Fastbin[0x80]:  => (nil)
          EOS
        end
      end
    end

    describe 'otherbin' do
      it 'unsorted' do
        @hs.each do |h|
          list = h.libc.main_arena.unsorted_bin.link_list 1
          expect(list).to eq [0x6021d0, h.libc.main_arena.unsorted_bin.base, 0x6021d0]
        end
      end

      it 'normal' do
        @hs.each do |h|
          list = h.libc.main_arena.smallbin[0].link_list 1
          base = h.libc.main_arena.smallbin[0].base
          expect(list).to eq [0x6020f0, base, 0x6020f0]
        end
      end

      it 'layouts' do
        @hs.each do |h|
          expect { h.layouts(:small, :unsorted) }.to output(<<-'EOS').to_stdout
UnsortedBin: 0x6021d0 === [self] === 0x6021d0
Smallbin[0x90]: 0x6020f0 === [self] === 0x6020f0
          EOS
        end
      end
    end
  end

  describe '32bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to make sure coverage
      @hs = @all_libs_heapinfo.call(32)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq 4
        expect(h.libc.main_arena.top_chunk.base).to eq 0x804b340
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7
      end
    end

    describe 'fastbin' do
      it 'normal' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[2].list).to eq [0x804b020, 0x804b000, nil]
        end
      end

      it 'invalid' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[4].list).to eq [0x804b040, 0xdeadbeef, :invalid]
        end
      end

      it 'loop' do
        @hs.each do |h|
          expect(h.libc.main_arena.fastbin[6].list).to eq [0x804b070, 0x804b0b0, 0x804b070, :loop]
        end
      end

      it 'fastbin' do
        @hs.each do |h|
          expect { h.layouts(:fastbin) }.to output(<<-'EOS').to_stdout
Fastbin[0x10]:  => (nil)
Fastbin[0x18]:  => (nil)
Fastbin[0x20]:  => 0x804b020 => 0x804b000 => (nil)
Fastbin[0x28]:  => (nil)
Fastbin[0x30]:  => 0x804b040 => 0xdeadbeef(invalid)
Fastbin[0x38]:  => (nil)
Fastbin[0x40]:  => 0x804b070 => 0x804b0b0 => 0x804b070(loop)
          EOS
        end
      end
    end

    describe 'otherbin' do
      it 'unsorted' do
        @hs.each do |h|
          list = h.libc.main_arena.unsorted_bin.link_list 1
          expect(list).to eq [0x804b1d0, h.libc.main_arena.unsorted_bin.base, 0x804b1d0]
        end
      end
      it 'normal' do
        @hs.each do |h|
          list = h.libc.main_arena.smallbin[9].link_list 1
          base = h.libc.main_arena.smallbin[9].base
          expect(list).to eq [0x804b0f0, base, 0x804b0f0]
        end
      end
      it 'layouts' do
        @hs.each do |h|
          expect { h.layouts(:small, :unsorted) }.to output(<<-'EOS').to_stdout
UnsortedBin: 0x804b1d0 === [self] === 0x804b1d0
Smallbin[0x90]: 0x804b0f0 === [self] === 0x804b0f0
          EOS
        end
      end
    end
  end
end
