# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Dumper do
  describe 'dump' do
    before(:each) do
      @mem_f = File.open('/proc/self/mem')
    end
    after(:each) do
      @mem_f.close
    end
    it 'simple' do
      expect(HeapInfo::Dumper.dump(nil, @mem_f, 0x400000, 4)).to eq "\x7fELF"
    end
    it 'segment' do
      segments = {elf: HeapInfo::Segment.new(0x400000, 'elf')}
      expect(HeapInfo::Dumper.dump(segments, @mem_f, :elf, 4)).to eq "\x7fELF"
    end
    it 'invalid' do
      expect(HeapInfo::Dumper.dump({}, @mem_f, :zzz, 1)).to be nil
      expect(HeapInfo::Dumper.dump({}, @mem_f, 0x12345, 1)).to be nil
    end
  end
  describe 'parse_cmd' do
    it 'normal' do
      expect(HeapInfo::Dumper.parse_cmd [0x30]).to eq [0x30, 0, 8]
      expect(HeapInfo::Dumper.parse_cmd [0x30, 3]).to eq [0x30, 0, 3]
      expect(HeapInfo::Dumper.parse_cmd [0x30, 2, 3]).to eq [0x30, 2, 3]
    end
    it 'symbol' do
      expect(HeapInfo::Dumper.parse_cmd [:heap]).to eq [:heap,0 , 8]
      expect(HeapInfo::Dumper.parse_cmd [:heap, 10]).to eq [:heap,0 , 10]
      expect(HeapInfo::Dumper.parse_cmd [:heap, 3, 10]).to eq [:heap,3 , 10]
    end 
    it 'string' do
      expect(HeapInfo::Dumper.parse_cmd ['heap']).to eq [:heap, 0, 8]
      expect(HeapInfo::Dumper.parse_cmd ['heap, 10']).to eq [:heap, 0, 10]
      expect(HeapInfo::Dumper.parse_cmd ['heap, 0x33, 10']).to eq [:heap, 51, 10]
      expect(HeapInfo::Dumper.parse_cmd ['heap+0x15, 10']).to eq [:heap, 0x15, 10]
      expect(HeapInfo::Dumper.parse_cmd ['heap + 0x15, 10']).to eq [:heap, 0x15, 10]
    end
    it 'mixed' do
      expect(HeapInfo::Dumper.parse_cmd ['heap+ 0x10', 10]).to eq [:heap, 0x10, 10]
      expect(HeapInfo::Dumper.parse_cmd ['heap', 10]).to eq [:heap, 0, 10]
    end
  end
end
