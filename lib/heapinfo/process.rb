#encoding: ascii-8bit
module HeapInfo
  class Process
    attr_reader :pid, :status
    def initialize(prog, libc)
      #TODO: support pass pid directly
      if prog.is_a?(String)
        @pid = Helper.pidof prog
        load_status libc
      end
      need_permission unless dumpable?
    end

    # example:
    # dump(:heap, 64)
    # dump(:heap, 0x100, 64)
    # dump('heap, 0x100')
    
    def dump(*args)
      return need_permission unless dumpable?
    end

    # use /proc/[pid]/mem for memory dump, must sure not be traced by others
    def dumpable?
      File.open("/proc/#{pid}/mem").close
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
        libc:    Segment.find(maps, maps.map{|s| s[3]}.find{|seg| libc.is_a?(Regexp) ? seg =~ libc : seg.include?(libc)}),
        heap:    Segment.find(maps, 'heap'),
        stack:   Segment.find(maps, 'stack'),
        arch: elf[4] == "\x01" ? '32' : '64',
      }
      @status.keys.each do |m|
        self.class.send(:define_method, m) {@status[m]}
      end
    end
    def need_permission
      puts Helper.color(%q(Could not attach to process.  If your uid matches the uid of the target process, check the setting of /proc/sys/kernel/yama/ptrace_scope, or try again as the root user.  For more details, see /etc/sysctl.d/10-ptrace.conf), sev: :fatal)
    end
  end
end
