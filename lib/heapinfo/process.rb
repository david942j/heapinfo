#encoding: ascii-8bit
module HeapInfo
  class Process
    DEFAULT_LIB = {
      libc: /libc[^\w]/,
      ld:   /\/ld-.+\.so/,
    }
    attr_reader :pid, :status
    def initialize(prog, options = {})
      if prog.is_a? String
        @pid = Helper.pidof prog
      elsif prog.is_a? Integer
        @pid = prog
      end
      load_status options.merge(DEFAULT_LIB)
      need_permission unless dumpable?
    end

    # example:
    # dump(:heap) # &heap[0, 8]
    # dump(:heap, 64) # &heap[0, 64]
    # dump(:heap, 256, 64) # &heap[256, 64]
    # dump('heap+256, 64') # &heap[256, 64]
    # dump('heap+0x100') # &heap[256, 8]
    # dump(:segment, 8) semgent can be [heap, stack, (program|elf), libc]
    # dump(addr, 64) # addr[0, 64]

    # invalid:
    # dump('meow') # no such segment
    # dump('heap-1, 64') # not support `-`
    
    def dump(*args)
      return need_permission unless dumpable?
      mem = Dumper.dump(@status, f = mem_f, *args)
      f.close
      mem
    end

    # dump_chunks take the dump result as chunks, and pretty print it
    def dump_chunks(*args)
      return need_permission unless dumpable?
      base, offset, _ = Dumper.parse_cmd(args)
      base = @status[base].base if @status[base].is_a? Segment
      dump(*args).to_chunks(bits: @status[:arch].to_i, base: base + offset)
    end

    def layouts(*args)
      self.libc.main_arena.layouts(*args)
    end

    def to_s
      "Program: #{Helper.color program.name} PID: #{Helper.color pid}\n" +
      program.to_s +
      heap.to_s + 
      stack.to_s +
      libc.to_s +
      ld.to_s
    end

    # for children to access memory
    def dumper
      Proc.new {|*args| self.dump(*args)}
    end

  private
    # use /proc/[pid]/mem for memory dump, must sure have permission
    def dumpable?
      mem_f.close
      true
    rescue => e
      if e.is_a? Errno::EACCES
        false
      else
        throw e
      end
    end

    def load_status(options)
      elf  = Helper.exe_of pid
      maps = Helper.parse_maps Helper.maps_of pid
      @status = {
        program: Segment.find(maps, File.readlink("/proc/#{pid}/exe")),
        libc:    Libc.find(maps, match_maps(maps, options[:libc]), self),
        heap:    Segment.find(maps, '[heap]'),
        stack:   Segment.find(maps, '[stack]'),
        ld:      Segment.find(maps, match_maps(maps, options[:ld])),
        arch:    bit(elf),
      }
      @status[:elf] = @status[:program] #alias
      @status.keys.each do |m|
        self.class.send(:define_method, m) {@status[m]}
      end
    end
    def match_maps(maps, pattern)
      maps.map{|s| s[3]}.find{|seg| pattern.is_a?(Regexp) ? seg =~ pattern : sef.include?(pattern)}
    end
    def bit(elf)
      elf[4] == "\x01" ? '32' : '64'
    end
    def mem_f
      File.open("/proc/#{pid}/mem")
    end
    def need_permission
      puts Helper.color(%q(Could not attach to process. Check the setting of /proc/sys/kernel/yama/ptrace_scope, or try again as the root user.  For more details, see /etc/sysctl.d/10-ptrace.conf), sev: :fatal)
    end
  end
end
