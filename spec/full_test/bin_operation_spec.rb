# encoding: ascii-8bit
# frozen_string_literal: true

require 'heapinfo'
describe "Bin's operation" do
  describe 'common' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @hs = @old_libs_heapinfo.call(64) + @old_libs_heapinfo.call(32)
    end

    it 'main_arena' do
      @hs.each do |h|
        expect(h.libc.main_arena.top_chunk.size_t).to eq h.bits / 8
        expect(h.libc.main_arena.top_chunk.base & 0xfff).to eq 0x340
        expect(h.libc.main_arena.system_mem).to eq 0x21000
        expect(h.libc.main_arena.fastbin.size).to eq 7

        expect(h.libc.tcache?).to be false
      end
    end

    describe 'fastbin' do
      it 'normal' do
        @hs.each do |h|
          i = h.bits == 32 ? 2 : 0
          heap = h.heap.base
          expect(h.libc.main_arena.fastbin[i].list).to eq [heap + 0x20, heap, nil]
        end
      end

      it 'invalid' do
        @hs.each do |h|
          i = h.bits == 32 ? 4 : 1
          heap = h.heap.base
          expect(h.libc.main_arena.fastbin[i].list).to eq [heap + 0x40, 0xdeadbeef, :invalid]
        end
      end

      it 'loop' do
        @hs.each do |h|
          i = h.bits == 32 ? 6 : 2
          heap = h.heap.base
          expect(h.libc.main_arena.fastbin[i].list).to eq [heap + 0x70, heap + 0xb0, heap + 0x70, :loop]
        end
      end
    end

    describe 'otherbin' do
      it 'unsorted' do
        @hs.each do |h|
          heap = h.heap.base
          list = h.libc.main_arena.unsorted_bin.link_list 1
          expect(list).to eq [heap + 0x1d0, h.libc.main_arena.unsorted_bin.base, heap + 0x1d0]
        end
      end

      it 'normal' do
        @hs.each do |h|
          i = h.bits == 32 ? 16 : 7
          heap = h.heap.base
          list = h.libc.main_arena.smallbin[i].link_list 1
          base = h.libc.main_arena.smallbin[i].base
          expect(list).to eq [heap + 0xf0, base, heap + 0xf0]
        end
      end
    end
  end

  describe '64bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @hs = @old_libs_heapinfo.call(64)
    end

    describe 'fastbin' do
      it 'layouts' do
        @hs.each do |h|
          heap = h.heap.base
          expect { h.layouts(:fastbin) }.to output(<<-EOS).to_stdout
Fastbin[0x20]:  => #{to_hex(heap + 0x20)} => #{to_hex(heap)} => (nil)
Fastbin[0x30]:  => #{to_hex(heap + 0x40)} => 0xdeadbeef(invalid)
Fastbin[0x40]:  => #{to_hex(heap + 0x70)} => #{to_hex(heap + 0xb0)} => #{to_hex(heap + 0x70)}(loop)
Fastbin[0x50]:  => (nil)
Fastbin[0x60]:  => (nil)
Fastbin[0x70]:  => (nil)
Fastbin[0x80]:  => (nil)
          EOS
        end
      end
    end

    describe 'otherbin' do
      it 'layouts' do
        @hs.each do |h|
          heap = h.heap.base
          expect { h.layouts(:small, :unsorted) }.to output(<<-EOS).to_stdout
UnsortedBin: #{to_hex(heap + 0x1d0)} === [self] === #{to_hex(heap + 0x1d0)}
Smallbin[0x90]: #{to_hex(heap + 0xf0)} === [self] === #{to_hex(heap + 0xf0)}
          EOS

          expect { h.layouts(:all) }.to output(<<-EOS).to_stdout
Fastbin[0x20]:  => #{to_hex(heap + 0x20)} => #{to_hex(heap)} => (nil)
Fastbin[0x30]:  => #{to_hex(heap + 0x40)} => 0xdeadbeef(invalid)
Fastbin[0x40]:  => #{to_hex(heap + 0x70)} => #{to_hex(heap + 0xb0)} => #{to_hex(heap + 0x70)}(loop)
Fastbin[0x50]:  => (nil)
Fastbin[0x60]:  => (nil)
Fastbin[0x70]:  => (nil)
Fastbin[0x80]:  => (nil)
UnsortedBin: #{to_hex(heap + 0x1d0)} === [self] === #{to_hex(heap + 0x1d0)}
Smallbin[0x90]: #{to_hex(heap + 0xf0)} === [self] === #{to_hex(heap + 0xf0)}
          EOS
        end
      end
    end
  end

  describe '32bit' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @hs = @old_libs_heapinfo.call(32)
    end

    describe 'fastbin' do
      it 'layouts' do
        @hs.each do |h|
          heap = h.heap.base
          expect { h.layouts(:fastbin) }.to output(<<-EOS).to_stdout
Fastbin[0x10]:  => (nil)
Fastbin[0x18]:  => (nil)
Fastbin[0x20]:  => #{to_hex(heap + 0x20)} => #{to_hex(heap)} => (nil)
Fastbin[0x28]:  => (nil)
Fastbin[0x30]:  => #{to_hex(heap + 0x40)} => 0xdeadbeef(invalid)
Fastbin[0x38]:  => (nil)
Fastbin[0x40]:  => #{to_hex(heap + 0x70)} => #{to_hex(heap + 0xb0)} => #{to_hex(heap + 0x70)}(loop)
          EOS
        end
      end
    end

    describe 'otherbin' do
      it 'layouts' do
        @hs.each do |h|
          heap = h.heap.base
          expect { h.layouts(:small, :unsorted) }.to output(<<-EOS).to_stdout
UnsortedBin: #{to_hex(heap + 0x1d0)} === [self] === #{to_hex(heap + 0x1d0)}
Smallbin[0x90]: #{to_hex(heap + 0xf0)} === [self] === #{to_hex(heap + 0xf0)}
          EOS
        end
      end
    end
  end
end
