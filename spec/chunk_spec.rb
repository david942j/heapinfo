# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Chunk do
  describe '32bit' do
    before(:all) do
      @fast = [0, 0x47, 0x1337].pack('L*').to_chunk(bits: 32)
      @small = [0, 0x48, 0xabcdef].pack('L*').to_chunk(bits: 32)
    end
    it 'basic' do
      expect(@fast.size_t).to be 4
      expect(@fast.size).to be 0x40
      expect(@fast.flags).to eq [:non_main_arena, :mmapped, :prev_inuse]
      expect(@fast.bintype).to eq :fast
      expect(@fast.data).to eq [0x1337].pack('L*')
      expect(@small.bintype).to eq :small
    end

    it 'to_s' do
      expect(@small.to_s).to eq "\e[38;5;155m#<HeapInfo::Chunk:0>\n" \
                                "\e[0mflags = []\nsize = \e[38;5;12m0x48\e[0m (small)\n" \
                                "prev_size = \e[38;5;12m0\e[0m\n" \
                                "data = \e[38;5;1m\"\\xEF\\xCD\\xAB\\x00\"\e[0m...\n"
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
      expect(@fast.flags).to eq [:non_main_arena, :mmapped, :prev_inuse]
      expect(@fast.bintype).to eq :fast
      expect(@fast.data).to eq [0x1337].pack('Q*')
      expect(@small.bintype).to eq :small
    end
    it 'to_s' do
      expect(@small.to_s).to eq "\e[38;5;155m#<HeapInfo::Chunk:0>\n" \
                                "\e[0mflags = []\nsize = \e[38;5;12m0x90\e[0m (small)\n" \
                                "prev_size = \e[38;5;12m0\e[0m\n" \
                                "data = \e[38;5;1m\"\\xAD\\xDE\\x00\\x00\\x00\\x00\\x00\\x00\"\e[0m...\n"
    end
  end
end
