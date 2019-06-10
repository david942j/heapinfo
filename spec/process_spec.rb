# encoding: ascii-8bit
# frozen_string_literal: true

require 'open3'

require 'heapinfo/process'

describe HeapInfo::Process do
  describe 'self' do
    before(:all) do
      @prog = File.readlink('/proc/self/exe')
      @h = described_class.new(@prog)
      @h.instance_variable_set(:@pid, 'self')
    end

    it 'segments' do
      expect(@h.elf.name).to eq @prog
      expect(@h.libc.class).to eq HeapInfo::Libc
      expect(@h.respond_to?(:heap)).to be true
      expect(@h.respond_to?(:ld)).to be true
      expect(@h.respond_to?(:stack)).to be true
    end

    it 'dump' do
      expect(@h.dump(:elf, 4)).to eq "\x7fELF"
    end

    it 'dump_chunks' do
      expect(@h.dump_chunks(:heap, 0x30).class).to be HeapInfo::Chunks
    end

    it 'offset' do
      libc_base = @h.libc.base
      heap_base = @h.heap.base
      expect { @h.offset(libc_base + 0x12345, :libc) }.to output("0x12345 after libc\n").to_stdout
      expect { @h.offset(libc_base + 0x12345) }.to output("0x12345 after libc\n").to_stdout
      expect { @h.offset(libc_base - 0xdeadbeef, :libc) }.to output("-0xdeadbeef after libc\n").to_stdout
      expect { @h.offset(heap_base) }.to output("0x0 after heap\n").to_stdout
      expect { @h.offset(0x123) }.to output("Invalid address 0x123\n").to_stdout
    end

    it 'canary' do
      # well.. how to check exactly value?
      expect(@h.canary & 0xff).to be_zero
    end

    it 'inspect' do
      expect(@h.inspect).to match(/^#<HeapInfo::Process:0x[0-9a-f]{16}>$/)
    end
  end

  describe 'victim' do
    before(:all) do
      HeapInfo::Cache.clear_all # force cache miss, to ensure coverage
      @victim = @compile_and_run.call(bit: 64, lib_ver: '2.23')
      @h = heapinfo(@victim)
    end

    it 'check process' do
      expect(@h.elf.name).to eq @victim
      pid = @h.pid
      expect(pid).to be_a Integer
      expect(described_class.new(pid).elf.name).to eq @h.elf.name
    end

    it 'x' do
      expect { @h.x(3, :heap) }.to output(<<-'EOS').to_stdout
0x602000:	0x0000000000000000	0x0000000000000021
0x602010:	0x0000000000000000
      EOS
      expect { @h.x(2, 'heap+0x20') }.to output(<<-'EOS').to_stdout
0x602020:	0x0000000000000000	0x0000000000000021
      EOS
    end

    it 's' do
      expect(@h.s(:elf)).to eq "\x7FELF\x02\x01\x01"
      expect(@h.s('heap+8')).to eq "\x21"
      expect(@h.s('heap-8')).to eq ''
    end

    it 'debug wrapper' do
      @h.instance_variable_set(:@pid, nil)
      # will reload pid
      expect(@h.debug { @h.to_s }).to eq @h.to_s
    end

    describe 'find/search' do
      it 'far away' do
        expect(@h.find('/bin/sh', :libc)).to be_a Integer
        # check coerce
        expect(@h.find('/bin/sh', :libc) - @h.libc).to eq 0x18cd57
        expect(@h.find('/bin/sh', :libc, rel: true)).to eq 0x18cd57
      end

      it 'value' do
        expect(@h.search(0xdeadbeef, :heap)).to eq 0x602050
      end

      it 'not found' do
        expect(@h.search(0xdeadbeef, :heap, 0x4f, rel: true)).to be nil
        expect(@h.search(0xdead1234ddddd, :heap)).to be nil
      end

      it 'string' do
        expect(@h.search("\xbe\xad", :heap)).to eq 0x602051
        expect(@h.search("\xbe\xad", :heap, rel: true)).to eq 0x51
      end

      it 'regexp' do
        expect(@h.search(/[^\x00]/, :heap)).to eq 0x602008
      end
    end

    describe 'find_all' do
      it 'integer' do
        expect { @h.find_all(0xdeadbeef) }.to output(<<-EOS).to_stdout
Searching 0xdeadbeef:
In [heap](0x602000-0x623000), permission=rw-
  0x602050
        EOS
      end

      it 'string' do
        expect { @h.findall("\xbe\xad\xde\x00") }.to output(<<-EOS).to_stdout
Searching "\\xBE\\xAD\\xDE\\x00":
In [heap](0x602000-0x623000), permission=rw-
  0x602051
        EOS
      end

      it 'canary' do
        expect { @h.find_all(@h.canary, :ld, :stack) }.to output(<<-EOS).to_stdout
Searching #{HeapInfo::Helper.hex(@h.canary)}:
In (0x7ffff7fd3000-0x7ffff7ff7000), permission=rw-
  0x7ffff7ff5728
        EOS
      end

      it 'canary' do
        expect { @h.find_all(@h.canary) }.to output(<<-EOS).to_stdout
Searching #{HeapInfo::Helper.hex(@h.canary)}:
In (0x7ffff7fd3000-0x7ffff7ff7000), permission=rw-
  0x7ffff7ff5728
In [stack](0x7ffffffdd000-0x7ffffffff000), permission=rw-
  0x7fffffffda28
        EOS
      end
    end

    describe 'reload' do
      it 'monkey' do
        prog = File.readlink('/proc/self/exe')
        h = described_class.new(prog)
        expect(h.pid).to be_a Integer
        pid = h.pid
        h.instance_variable_set(:@prog, 'NO_THIS')
        expect(h.reload!.pid).to be nil
        h.instance_variable_set(:@prog, prog)
        expect(h.reload.pid).to be pid
      end

      it 'new process' do
        prog = 'cat'
        stdin, _, _, wait_thr = Open3.popen3(prog)
        h = described_class.new(prog)
        pid = wait_thr[:pid]
        expect(h.pid).to be pid
        stdin.close
        expect(wait_thr.value.exitstatus).to be_zero

        expect(h.reload.pid).to be_nil

        stdin, _, _, wait_thr = Open3.popen3(prog)
        pid2 = wait_thr[:pid]
        expect(h.reload.pid).to be pid2
        expect(h.to_s).to include prog
        stdin.close
        expect(wait_thr.value.exitstatus).to be_zero
      end
    end

    describe 'chunks' do
      before(:all) do
        mmap_addr = HeapInfo::Helper.unpack(8, @h.dump(':heap+0x190', 8))
        @mmap_chunk = @h.dump(mmap_addr - 0x10, 0x20).to_chunk(base: mmap_addr - 0x10)
      end

      it 'mmap' do
        expect(@mmap_chunk.base & 0xfff).to be 0
        expect(@mmap_chunk.bintype).to eq :mmap
        expect(@mmap_chunk.flags).to eq [:mmapped]
        expect(@mmap_chunk.to_s).to include ':mmapped'
      end
    end
  end

  describe 'static-link' do
    before(:all) do
      victim = @compile_and_run.call(flags: '-static')
      @h = heapinfo(victim)
    end

    it 'normal' do
      expect(@h.libc).to be_a HeapInfo::Nil
      expect(@h.ld).to be_a HeapInfo::Nil
    end

    it 'dump' do
      expect(@h.dump(:elf, 4)).to eq "\x7fELF"
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
      expect(@h.debug { raise }).to be nil
    end

    it 'nil chain' do
      expect(@h.dump(:heap).no_such_method.xdd.nil?).to be true
    end

    it 'info methods' do
      expect(@h.libc.base.nil?).to be true
    end
  end
end
