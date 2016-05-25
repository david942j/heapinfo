#encoding: ascii-8bit
module HeapInfo
  class Process
    attr_reader :pid, :status
    def initialize(prog, libc)
      if prog.is_a? String
        @pid = Helper.pidof prog
      elsif prog.is_a? Integer
        @pid = prog
      end
      load_status libc
      need_permission unless dumpable?
    end

    # example:
    # dump(:heap) # &heap[0, 8]
    # dump(:heap, 64) # &heap[0, 64]
    # dump(:heap, 256, 64) # &heap[256, 64]
    # dump('heap+256, 64') # &heap[256, 64]
    # dump('heap+0x100') # &heap[256, 8]
    # if argument `heap` is present, dumper will try to mark chunks and pretty the output
    # dump(:segment, 8) semgent can be [heap, stack, (program|elf), libc]
    # dump(addr, 64) # addr[0, 64]

    # invalid:
    # dump('meow') # no such segment
    # dump('heap-1, 64') # not support `-`
    # dump('heap+123, 256, 64') # parser will take it same as 'heap+123, 64'
    
    def dump(*args)
      return need_permission unless dumpable?
      mem = Dumper.dump(@status, f = mem_f, *args)
      # remember to close file so that still can be traced by gdb or other tracers
      f.close
      mem
    end

    # use /proc/[pid]/mem for memory dump, must sure not be traced by others
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

    def interact
      #TODO
    end
    alias :interactive :interact

    def to_s
      "Program: #{Helper.color program.name} PID: #{Helper.color pid}\n" +
      program.to_s +
      heap.to_s + 
      stack.to_s +
      libc.to_s
    end

  private
    def load_status(libc)
      sta  = Helper.status_of pid
      elf  = Helper.exe_of pid
      maps = Helper.parse_maps Helper.maps_of pid
      @status = {
        program: Segment.find(maps, File.readlink("/proc/#{pid}/exe")),
        libc:    Libc.find(maps, maps.map{|s| s[3]}.find{|seg| libc.is_a?(Regexp) ? seg =~ libc : seg.include?(libc)}, self),
        heap:    Segment.find(maps, 'heap'),
        stack:   Segment.find(maps, 'stack'),
        arch: elf[4] == "\x01" ? '32' : '64',
      }
      @status[:elf] = @status[:program] #alias
      @status.keys.each do |m|
        self.class.send(:define_method, m) {@status[m]}
      end
    end
    def mem_f
      File.open("/proc/#{pid}/mem")
    end
    def need_permission
      puts Helper.color(%q(Could not attach to process. Check the setting of /proc/sys/kernel/yama/ptrace_scope, or try again as the root user.  For more details, see /etc/sysctl.d/10-ptrace.conf), sev: :fatal)
    end
  end
end
