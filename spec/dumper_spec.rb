# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Dumper do
  describe 'dump' do
    before(:each) do
      @mem_filename = '/proc/self/mem'
    end
    it 'simple' do
      dumper = HeapInfo::Dumper.new(nil, @mem_filename)
      expect(dumper.dump(0x400000, 4)).to eq "\x7fELF"
    end
    it 'segment' do
      class S;def elf; HeapInfo::Segment.new(0x400000, 'elf'); end; end
      dumper = HeapInfo::Dumper.new(S.new, @mem_filename)
      expect(dumper.dump(:elf, 4)).to eq "\x7fELF"
    end
    it 'invalid' do
      dumper = HeapInfo::Dumper.new(HeapInfo::Nil.new, @mem_filename)
      expect(dumper.dump(:zzz, 1)).to be nil
      expect(dumper.dump(0x12345, 1)).to be nil
    end
  end

  it 'dumpable?' do
    dumper = HeapInfo::Dumper.new(HeapInfo::Nil.new, '/proc/self/mem')
    expect(dumper.send(:dumpable?)).to be true
    # a little hack
    dumper.instance_variable_set(:@filename, '/proc/1/mem')
    expect(dumper.send(:dumpable?)).to be false
    expect(dumper.dump).to be nil # show need permission
    dumper.instance_variable_set(:@filename, '/proc/-1/mem')
    expect {dumper.send(:dumpable?)}.to raise_error ArgumentError
  end

  describe 'find' do
    before(:all) do
      class S;def elf; HeapInfo::Segment.new(0x400000, ''); end; def bits; 64; end; end
      @dumper = HeapInfo::Dumper.new(S.new, '/proc/self/mem')
    end
    it 'simple' do
      expect(@dumper.find("ELF", :elf, 4)).to eq 0x400001
      expect(@dumper.find("ELF", :elf, 3)).to be nil
    end
    it 'regexp' do
      addr = @dumper.find(/ru.y/, :elf, 0x1000)
      expect(@dumper.dump(addr, 4) =~ /ru.y/).to eq 0
    end
    it 'invalid' do
      expect(@dumper.find(nil, :elf, 1)).to be nil
    end
    it 'parser' do
      expect(@dumper.find("ELF", ':elf + 1', 3)).to eq 0x400001
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
      expect(HeapInfo::Dumper.parse_cmd ['heap +  0x15']).to eq [:heap, 0x15, 8]
    end
    it 'mixed' do
      expect(HeapInfo::Dumper.parse_cmd ['heap+ 0x10', 10]).to eq [:heap, 0x10, 10]
      expect(HeapInfo::Dumper.parse_cmd ['heap', 10]).to eq [:heap, 0, 10]
    end
  end
end
