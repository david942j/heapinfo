#encoding: ascii-8bit
module HeapInfo
  # for <tt>Process</tt> to record current info(s)
  # <tt>Process</tt> has a <tt>process_info</tt> object iff the process found (pid not <tt>nil</tt>).
  # Mainly records segments' base.
  class ProcessInfo
    # Methods to be transparent to <tt>process</tt>.
    # e.g. <tt>process.libc alias to process.info.libc</tt>
    EXPORT = %i(libc ld heap elf program stack bits)
   
    attr_reader :bits, :program, :stack, :libc, :ld
    alias :elf :program

    # Instantiate a <tt>ProcessInfo</tt> object
    #
    # @param [HeapInfo::Process] process Load information from maps/memory for <tt>process</tt>
    def initialize(process)
      @pid = process.pid
      options = process.instance_variable_get(:@options)
      maps!
      @bits = bits_of Helper.exe_of @pid
      @elf = @program = Segment.find(maps, File.readlink("/proc/#{@pid}/exe"))
      @stack = Segment.find(maps, '[stack]')
      # well.. stack is a strange case because it will grow in runtime..
      # should i detect stack base growing..?
      @libc = Libc.find(maps, match_maps(maps, options[:libc]), process)
      @ld = Segment.find(maps, match_maps(maps, options[:ld]))
    end

    # Heap will not be mmapped if the process not use heap yet, so create a lazy loading method.
    # Will re-read maps when heap segment not found yet.
    #
    # @return [HeapInfo::Segment] The <tt>Segment</tt> of heap
    def heap # special handle because heap might not be initialized in the beginning
      @heap ||= Segment.find(maps!, '[heap]')
    end

  private
    attr_reader :maps

    # force reload maps
    def maps!
      @maps = Helper.parse_maps Helper.maps_of @pid
    end

    def bits_of(elf)
      elf[4] == "\x01" ? 32 : 64
    end

    def match_maps(maps, pattern)
      maps.map{|s| s[3]}.find{|seg| pattern.is_a?(Regexp) ? seg =~ pattern : seg.include?(pattern)}
    end
  end
end
