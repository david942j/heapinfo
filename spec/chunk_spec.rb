# encoding: ascii-8bit
# frozen_string_literal: true

require 'heapinfo/chunk'

describe HeapInfo::Chunk do
  describe '32bit' do
    before(:all) do
      @fast = [0, 0x47, 0x1337].pack('L*').to_chunk(bits: 32)
      @small = [0, 0x48, 0xabcdef].pack('L*').to_chunk(bits: 32)
    end
    it 'basic' do
      expect(@fast.size_t).to be 4
      expect(@fast.size).to be 0x40
      expect(@fast.flags).to eq %i[non_main_arena mmapped prev_inuse]
      expect(@fast.non_main_arena? && @fast.mmapped? && @fast.prev_inuse?).to be true
      expect(@fast.bintype).to eq :fast
      expect(@fast.data).to eq [0x1337].pack('L*')
      expect(@small.bintype).to eq :small
    end

    it 'to_s' do
      expect(@small.to_s).to eq(<<-EOS)
#<HeapInfo::Chunk:0>
flags = []
size = 0x48 (small)
prev_size = 0
data = "\\xEF\\xCD\\xAB\\x00\"...
      EOS
    end
  end

  describe '64bit' do
    before(:all) do
      @fast = [0, 0x87, 0x1337].pack('Q*').to_chunk # default 64bits
      @small = [0, 0x90, 0xdead].pack('Q*').to_chunk
    end

    it 'basic' do
      expect(@fast.size_t).to be 8
      expect(@fast.size).to be 0x80
      expect(@fast.flags).to eq %i[non_main_arena mmapped prev_inuse]
      expect(@fast.non_main_arena? && @fast.mmapped? && @fast.prev_inuse?).to be true
      expect(@fast.bintype).to eq :fast
      expect(@fast.data).to eq [0x1337].pack('Q*')
      expect(@small.bintype).to eq :small
    end

    it 'to_s' do
      expect(@small.to_s).to eq <<-EOS
#<HeapInfo::Chunk:0>
flags = []
size = 0x90 (small)
prev_size = 0
data = "\\xAD\\xDE\\x00\\x00\\x00\\x00\\x00\\x00\"...
      EOS
    end
  end
end
