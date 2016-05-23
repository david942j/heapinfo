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
    end

  private
    def load_status(libc)
      sta  = Helper.status_of pid
      elf  = Helper.exe_of pid
      maps = Helper.parse_maps Helper.maps_of pid
       
      @status = {
        program: Segment.find(maps, File.readlink("/proc/#{pid}/exe")),
        libc: Segment.find(maps, maps.map{|s| s[3]}.find{|seg| seg.include? libc}),
        arch: elf[4] == "\x01" ? '32' : '64',
      }
    end
  end
end
