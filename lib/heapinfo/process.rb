#encoding: ascii-8bit
module HeapInfo
  class Process
    DEFAULT_LIB = {
      libc: /libc[^\w]/,
      ld:   /\/ld-.+\.so/,
    }
    attr_reader :pid, :status
    def initialize(prog, options = {})
      @prog = prog
      @options = DEFAULT_LIB.merge options
      load!
      return unless load?
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
      return unless load?
      return need_permission unless dumpable?
      mem = Dumper.dump(@status, f = mem_f, *args)
      f.close
      mem
    end

    # return the dump result as chunks
    def dump_chunks(*args)
      return unless load?
      return need_permission unless dumpable?
      base, offset, _ = Dumper.parse_cmd(args)
      base = @status[base].base if @status[base].is_a? Segment
      dump(*args).to_chunks(bits: @status[:arch].to_i, base: base + offset)
    end

    def layouts(*args)
      return unless load?
      self.libc.main_arena.layouts(*args)
    end

    def to_s
      return "Process not found" unless load?
      "Program: #{Helper.color program.name} PID: #{Helper.color pid}\n" +
      program.to_s +
      heap.to_s + 
      stack.to_s +
      libc.to_s +
      ld.to_s
    end

    def debug
      return unless load!
      yield if block_given?
    end

  private
    def load?
      @pid != nil
    end

    def load! # force load is not efficient
      @pid = fetch_pid
      return false if @pid.nil? # still can't load
      load_status @options
      true
    end

    def fetch_pid
      pid = nil
      if @prog.is_a? String
        pid = Helper.pidof @prog
      elsif @prog.is_a? Integer
        pid = @prog
      end
      pid
    end

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
      maps.map{|s| s[3]}.find{|seg| pattern.is_a?(Regexp) ? seg =~ pattern : seg.include?(pattern)}
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
    def dumper
      Proc.new {|*args| self.dump(*args)}
    end
  end
end
