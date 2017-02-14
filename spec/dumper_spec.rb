# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Dumper do
  before(:all) do
    class S
      def initialize(base); @base = base
      end

      def elf; HeapInfo::Segment.new(@base, 'elf')
      end

      def bits; 64
      end
    end

    @self_maps = IO.binread('/proc/self/maps').lines.map do |seg|
      s = seg.split(/\s/)
      s[0] = s[0].split('-').map { |addr| addr.to_i(16) }
      [s[0][0], s[0][1], s[1], s[-1]] # start, end, perm, name
    end

    @get_elf_base = lambda do
      exe = File.readlink('/proc/self/exe')
      @self_maps.find { |arr| arr[3] == exe }[0]
    end
  end

  describe 'dump' do
    before(:each) do
      @mem_filename = '/proc/self/mem'
      @elf_base = @get_elf_base.call
    end
    it 'simple' do
      dumper = HeapInfo::Dumper.new(nil, @mem_filename)
      expect(dumper.dump(@elf_base, 4)).to eq "\x7fELF"
    end
    it 'segment' do
      dumper = HeapInfo::Dumper.new(S.new(@elf_base), @mem_filename)
      expect(dumper.dump(:elf, 4)).to eq "\x7fELF"
    end
    it 'invalid' do
      dumper = HeapInfo::Dumper.new(HeapInfo::Nil.new, @mem_filename)
      expect { dumper.dump(:zzz, 1) }.to raise_error ArgumentError
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
    expect { dumper.send(:dumpable?) }.to raise_error ArgumentError
  end

  describe 'find' do
    before(:all) do
      @elf_base = @get_elf_base.call
      @dumper = HeapInfo::Dumper.new(S.new(@elf_base), '/proc/self/mem')
      @end_of_maps = lambda do
        @self_maps.find.with_index do |seg, i|
          seg[2].include?('r') && seg[1] != @self_maps[i][0] # incontinuously segment
        end[1]
      end
    end
    it 'simple' do
      expect(@dumper.find('ELF', :elf, 4)).to eq @elf_base + 1
      expect(@dumper.find('ELF', :elf, 3)).to be nil
    end
    it 'regexp' do
      addr = @dumper.find(/lin.x/, :elf, 0x1000)
      expect(@dumper.dump(addr, 5) =~ /lin.x/).to eq 0
    end
    it 'invalid' do
      expect(@dumper.find(nil, :elf, 1)).to be nil
    end
    it 'parser' do
      expect(@dumper.find('ELF', ':elf + 1', 3)).to eq @elf_base + 1
    end
    it 'reach end' do
      mem = @end_of_maps.call
      # check dumper won't return nil when remain readable memory less than one page
      expect(@dumper.find("\x00", mem - 0xff0, 0x1000).nil?).to be false
    end
  end

  describe 'parse_cmd' do
    it 'normal' do
      expect(HeapInfo::Dumper.parse_cmd([0x30])).to eq [0x30, 0, 8]
      expect(HeapInfo::Dumper.parse_cmd([0x30, 3])).to eq [0x30, 0, 3]
      expect(HeapInfo::Dumper.parse_cmd([0x30, 2, 3])).to eq [0x30, 2, 3]
    end
    it 'symbol' do
      expect(HeapInfo::Dumper.parse_cmd([:heap])).to eq [:heap, 0, 8]
      expect(HeapInfo::Dumper.parse_cmd([:heap, 10])).to eq [:heap, 0, 10]
      expect(HeapInfo::Dumper.parse_cmd([:heap, 3, 10])).to eq [:heap, 3, 10]
    end
    it 'string' do
      expect(HeapInfo::Dumper.parse_cmd(['heap'])).to eq [:heap, 0, 8]
      expect(HeapInfo::Dumper.parse_cmd(['heap, 10'])).to eq [:heap, 0, 10]
      expect(HeapInfo::Dumper.parse_cmd(['heap, 0x33, 10'])).to eq [:heap, 51, 10]
      expect(HeapInfo::Dumper.parse_cmd(['heap+0x15, 10'])).to eq [:heap, 0x15, 10]
      expect(HeapInfo::Dumper.parse_cmd(['heap + 0x15, 10'])).to eq [:heap, 0x15, 10]
      expect(HeapInfo::Dumper.parse_cmd(['heap +  0x15'])).to eq [:heap, 0x15, 8]
    end
    it 'mixed' do
      expect(HeapInfo::Dumper.parse_cmd(['heap+ 0x10', 10])).to eq [:heap, 0x10, 10]
      expect(HeapInfo::Dumper.parse_cmd(['heap', 10])).to eq [:heap, 0, 10]
    end
  end
end
