# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Process do
  before(:all) do
    @prog = File.readlink('/proc/self/exe')
    @h = HeapInfo::Process.new(@prog)
    @h.instance_variable_set(:@pid, 'self')
  end
  it 'basic' do
    expect(@h.to_s).to include 'Program'
  end

  it 'segments' do
    expect(@h.elf.name).to eq @prog
    expect(@h.libc.class).to eq HeapInfo::Libc
    expect(@h.respond_to? :heap).to be true
    expect(@h.respond_to? :ld).to be true
    expect(@h.respond_to? :stack).to be true
  end
 
  it 'dump' do
    expect(@h.dump(:elf, 4)).to eq "\x7fELF"
  end

  describe 'main_arena' do
    before(:all) do
      expect(%x(gcc 2>&1)).to eq "gcc: fatal error: no input files\ncompilation terminated.\n"
    end
    it 'main_arena' do
      expect(@h.libc.main_arena.top_chunk.size_t).to eq 8
      expect(@h.libc.main_arena.fastbin.size).to eq 7
    end

    it 'layouts' do
      fast = @h.libc.main_arena.fastbin_layout
      unsorted = @h.libc.main_arena.unsorted_layout
      small = @h.libc.main_arena.smallbin_layout
      expect(fast).to include "Fastbin"
      expect(unsorted).to include "UnsortedBin"
      expect(@h.layouts :fastbin, :unsorted_bin, :smallbin).to include "UnsortedBin"
    end
  end
end
