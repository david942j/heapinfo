# encoding: ascii-8bit

require 'heapinfo'
describe HeapInfo::Dumper do
  before(:all) do
    @get_block = lambda do |base|
      methods = {
        elf: HeapInfo::Segment.new(base, 'elf'),
        bits: 64
      }
      methods[:segments] = { elf: methods[:elf] }
      ->(sym) { methods[sym] }
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
      dumper = HeapInfo::Dumper.new(@mem_filename)
      expect(dumper.dump(@elf_base, 4)).to eq "\x7fELF"
    end
    it 'segment' do
      dumper = HeapInfo::Dumper.new(@mem_filename, &@get_block.call(@elf_base))
      expect(dumper.dump(:elf, 4)).to eq "\x7fELF"
    end
    it 'invalid' do
      dumper = HeapInfo::Dumper.new(@mem_filename)
      expect { dumper.dump(:zzz, 1) }.to raise_error ArgumentError
      expect(dumper.dump(0x12345, 1)).to be nil
    end
  end

  it 'dumpable?' do
    dumper = HeapInfo::Dumper.new('/proc/self/mem')
    expect(dumper.__send__(:dumpable?)).to be true
    # a little hack
    dumper.instance_variable_set(:@filename, '/proc/1/mem')
    expect(dumper.__send__(:dumpable?)).to be false
    expect(dumper.dump).to be nil # show need permission
  end

  describe 'find' do
    before(:all) do
      @elf_base = @get_elf_base.call
      @dumper = HeapInfo::Dumper.new('/proc/self/mem', &@get_block.call(@elf_base))
      @end_of_maps = lambda do
        @self_maps.find.with_index do |seg, i|
          seg[2].include?('r') && seg[1] != @self_maps[i][0] # incontinuously segment
        end[1]
      end
    end
    it 'simple' do
      expect(@dumper.find('ELF', :elf, 4, false)).to eq @elf_base + 1
      expect(@dumper.find('ELF', :elf, 3, false)).to be nil
    end
    it 'regexp' do
      addr = @dumper.find(/lin.x/, :elf, 0x1000, false)
      expect(@dumper.dump(addr, 5) =~ /lin.x/).to eq 0
    end
    it 'invalid' do
      expect(@dumper.find(nil, :elf, 1, false)).to be nil
    end
    it 'parser' do
      expect(@dumper.find('ELF', ':elf + 1', 3, false)).to eq @elf_base + 1
    end
    it 'reach end' do
      mem = @end_of_maps.call
      # check dumper won't return nil when remain readable memory less than one page
      expect(@dumper.find("\x00", mem - 0xff0, 0x1000, false).nil?).to be false
    end
  end

  describe 'base_len_of' do
    before(:all) do
      @elf_base = @get_elf_base.call
      @dumper = HeapInfo::Dumper.new('/proc/self/mem', &@get_block.call(@elf_base))
    end

    it 'normal' do
      expect(@dumper.__send__(:base_len_of, 123, 321)).to eq [123, 321]
      expect(@dumper.__send__(:base_len_of, 123)).to eq [123, 8]
    end

    it 'segment' do
      expect(@dumper.__send__(:base_len_of, :elf, 10)).to eq [@elf_base, 10]
    end

    it 'eval' do
      expect(@dumper.__send__(:base_len_of, 'elf+0x30', 10)).to eq [@elf_base + 48, 10]
      expect(@dumper.__send__(:base_len_of, 'elf+0x3*2 - 1', 10)).to eq [@elf_base + 5, 10]
    end
  end
end
