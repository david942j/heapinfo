#encoding: ascii-8bit
module HeapInfo
  class Process
    attr_reader :pid, :status
    def initialize(prog)
      #TODO: support pass pid directly
      if prog.is_a?(String)
        @pid = HeapInfo::Helper.pidof(prog)
        load_status
      end
    end

  private
    def load_status
      sta = HeapInfo::Helper.status_of(@pid) 
      exe = HeapInfo::Helper.exe_of(@pid)
      @status = {
        progname: sta.scan(/^Name:\t(.+)$/)[0][0], #Name: $progname 
        arch: exe[4] == "\x01" ? '32' : '64'
      }
    end
  end
end
