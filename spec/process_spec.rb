# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Process do
  describe 'self' do
    before(:all) do
      @prog = File.readlink('/proc/self/exe')
      @h = HeapInfo::Process.new(@prog)
      @h.instance_variable_set(:@pid, 'self')
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

    it 'dump_chunks' do
      expect(@h.dump_chunks(:heap, 0x30).class).to be HeapInfo::Chunks
    end

    it 'dumpable?' do
      expect(@h.send(:dumpable?)).to be true
      # a little hack
      @h.instance_variable_set(:@pid, 1)
      expect(@h.send(:dumpable?)).to be false
      expect(@h.dump).to be nil # show need permission
      @h.instance_variable_set(:@pid, -1)
      expect {@h.send(:dumpable?)}.to raise_error ArgumentError
      @h.instance_variable_set(:@pid, 'self')
    end
  end

  describe 'victim' do
    before(:all) do
      @victim = HeapInfo::TMP_DIR + '/victim'
      %x(g++ #{File.expand_path('../files/victim.cpp', __FILE__)} -o #{@victim} 2>&1 > /dev/null)
      pid = fork
      # run without ASLR
      exec "setarch `uname -m` -R /bin/sh -c #{@victim}" if pid.nil?
      loop until `pidof #{@victim}` != '' 
      @h = heapinfo(@victim, ld: '/ld')
      class Cio;def puts(s);s;end;end
      @io = Cio.new
    end
    after(:all) do
      %x(killall #{@victim})
      FileUtils.rm(@victim)
    end

    it 'check process' do
      expect(@h.elf.name).to eq @victim
      pid = @h.pid
      expect(pid.is_a? Integer).to be true
      expect(HeapInfo::Process.new(pid).elf.name).to eq @h.elf.name
    end

    it 'x' do
      expect(@h.x 3, :heap, io: @io).to eq "0x602000:\t\e[38;5;12m0x0000000000000000\e[0m\t\e[38;5;12m0x0000000000000021\e[0m\n0x602010:\t\e[38;5;12m0x0000000000000000\e[0m"
      expect(@h.x 2, 'heap+0x20', io: @io).to eq "0x602020:\t\e[38;5;12m0x0000000000000000\e[0m\t\e[38;5;12m0x0000000000000021\e[0m"
    end

    it 'debug wrapper' do
      @h.instance_variable_set(:@pid, nil)
      # will reload pid
      expect(@h.debug { @h.to_s }).to eq @h.to_s
    end

    it 'main_arena' do
      expect(@h.libc.main_arena.top_chunk.size_t).to eq 8
      expect(@h.libc.main_arena.fastbin.size).to eq 7
    end

    describe 'fastbin' do
      it 'normal' do
        expect(@h.libc.main_arena.fastbin[0].list).to eq [0x602020, 0x602000, nil]
      end

      it 'invalid' do
        expect(@h.libc.main_arena.fastbin[1].list).to eq [0x602040, 0xdeadbeef, :invalid]
      end

      it 'loop' do
        expect(@h.libc.main_arena.fastbin[2].list).to eq [0x602070, 0x6020b0, 0x602070, :loop]
      end

      it 'fastbin' do
        lay = @h.layouts :fastbin, io: @io
        expect(lay).to include '0xdeadbeef'
        expect(lay).to include '(nil)'
        expect(lay).to include '(invalid)'
        expect(lay).to include '(loop)'
      end
    end

    describe 'otherbin' do
      it 'unsorted' do
        list = @h.libc.main_arena.unsorted_bin.link_list 1
        expect(list).to eq [0x6021d0, @h.libc.main_arena.unsorted_bin.base, 0x6021d0]
      end
      it 'normal' do
        list = @h.libc.main_arena.smallbin[0].link_list 1
        base = @h.libc.main_arena.smallbin[0].base
        expect(list).to eq [0x6020f0, base, 0x6020f0]
      end
      it 'layouts' do
        inspect = @h.layouts :smallbin, :unsorted_bin, io: @io
        expect(inspect).to include "[self]"
        expect(inspect).to include '0x6020f0'
        expect(inspect).to include 'UnsortedBin'
      end
    end

    describe 'chunks' do
      before(:all) do
        mmap_addr = HeapInfo::Helper.unpack(8, @h.dump(:heap, 0x190, 8))
        @mmap_chunk = @h.dump(mmap_addr-0x10, 0x20).to_chunk(base: mmap_addr-0x10)
      end
      it 'mmap' do
        expect(@mmap_chunk.base & 0xfff).to be 0
        expect(@mmap_chunk.bintype).to eq :mmap
        expect(@mmap_chunk.flags).to eq [:mmapped]
        expect(@mmap_chunk.to_s).to include ':mmapped'
      end
    end
  end
  
  describe 'no process' do
    before(:all) do
      @h = heapinfo('NO_SUCH_PROCESS~~~')
    end
    it 'dump like' do
      expect(@h.dump(:heap).nil?).to be true
      expect(@h.dump_chunks(:heap).nil?).to be true
    end

    it 'debug wrapper' do
      expect(@h.debug{ fail }).to be nil
    end

    it 'nil chain' do
      expect(@h.dump(:heap).no_such_method.xdd.nil?).to be true
    end
  end
end
