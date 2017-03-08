# encoding: ascii-8bit
module HeapInfo
  # Main class of heapinfo.
  class Process
    # The default options of libraries,
    # use for matching glibc and ld segments in +/proc/[pid]/maps+.
    DEFAULT_LIB = {
      libc: /bc[^a-z]*\.so/,
      ld:   %r{/ld-.+\.so}
    }.freeze
    # @return [Fixnum, NilClass] return the pid of process, +nil+ if no such process found
    attr_reader :pid

    # Instantiate a {HeapInfo::Process} object.
    # @param [String, Fixnum] prog Process name or pid, see {HeapInfo::heapinfo} for more information
    # @param [Hash{Symbol => RegExp, String}] options libraries' filename, see {HeapInfo::heapinfo} for more information
    def initialize(prog, options = {})
      @prog = prog
      @options = DEFAULT_LIB.merge options
      load!
      return unless load?
    end

    # Reload a new process with same program name
    #
    # @return [HeapInfo::Process] return +self+ for chainable.
    # @example
    #   puts h.reload!
    def reload!
      @pid = nil
      load!
      self
    end

    # Use this method to wrapper all HeapInfo methods.
    #
    # Since {HeapInfo} is a tool(debugger) for local usage,
    # while exploiting remote service, all methods will not work properly.
    # So I suggest to wrapper all methods inside {#debug},
    # which will ignore the block while the victim process is not found.
    #
    # @example
    #   h = heapinfo('./victim') # such process doesn't exist
    #   libc_base = leak_libc_base_of_victim # normal exploit
    #   h.debug {
    #     # for local to check if exploit correct
    #     fail('libc_base') unless libc_base == h.libc.base
    #   }
    #   # block of #debug will not execute if can't found process
    def debug
      return unless load!
      yield if block_given?
    end

    # Dump the content of specific memory address.
    #
    # Note: This method require you have permission of attaching another process.
    # If not, a warning message will present.
    #
    # @param [Mixed] args Will be parsed into +[base, length]+, see Examples for more information.
    # @return [String, HeapInfo::Nil]
    #   The content needed. When the request address is not readable or the process not exists,
    #   instance of {HeapInfo::Nil} is returned.
    #
    # @example
    #   h = heapinfo('victim')
    #   h.dump(:heap) # heap[0, 8]
    #   h.dump(:heap, 64) # heap[0, 64]
    #   h.dump('heap+256', 64)  # heap[256, 64]
    #   h.dump('heap+0x100', 64) # heap[256, 64]
    #   h.dump('heap+0x100 * 2 + 0x300', 64) # heap[1024, 64]
    #   h.dump(<segment>, 8) # semgent can be [heap, stack, (program|elf), libc, ld]
    #   h.dump(addr, 64) # addr[0, 64]
    #
    #   # Invalid usage
    #   dump(:meow) # no such segment
    def dump(*args)
      return Nil.new unless load?
      dumper.dump(*args)
    end

    # Return the dump result as chunks.
    # see {HeapInfo::Dumper#dump_chunks} for more information.
    #
    # @return [HeapInfo::Chunks, HeapInfo::Nil] An array of chunk(s).
    # @param [Mixed] args Same as arguments of {#dump}.
    def dump_chunks(*args)
      return Nil.new unless load?
      dumper.dump_chunks(*args)
    end

    # Show the offset in pretty way between the segment.
    # Very useful in pwn when leak some address,
    # see examples for more details.
    # @param [Integer] addr The leaked address.
    # @param [Symbol] sym
    #   The segement symbol to be calculated offset.
    #   If this parameter not given, will loop segments
    #   and find the most close one. See examples for more details.
    # @return [void] Offset will show to stdout.
    # @example
    #   h.offset(0x7f11f6ae1670, :libc)
    #   #=> 0xf6670 after libc
    #   h.offset(0x5559edc057a0, :heap)
    #   #=> 0x9637a0 after heap
    #   h.offset(0x7f11f6ae1670)
    #   #=> 0xf6670 after :libc
    #   h.offset(0x5559edc057a0)
    #   #=> 0x9637a0 after :heap
    def offset(addr, sym = nil)
      return unless load?
      segment = @info.send(sym) if HeapInfo::ProcessInfo::EXPORT.include?(sym)
      segment = nil unless segment.is_a?(HeapInfo::Segment)
      if segment.nil?
        sym, segment = @info.segments.select { |_, seg| seg.base <= addr }.min_by { |_, seg| addr - seg.base }
      end
      return puts "Invalid address #{Helper.hex(addr)}" if segment.nil?
      puts Helper.color(Helper.hex(addr - segment.base)) + ' after ' + Helper.color(sym, sev: :sym)
    end

    # Gdb-like command
    #
    # Show dump results like gdb's command +x+.
    # While will auto detect the current elf class to decide using +gx+ or +wx+.
    #
    # The dump results wrapper with color codes and nice typesetting will output to +stdout+.
    # @param [Integer] count The number of result need to dump, see examples for more information.
    # @param [String, Symbol, Integer] address The base address to be dumped.
    #   Same format as {#dump(*args)}, see {#dump} for more information.
    # @return [void]
    # @example
    #   h.x 8, :heap
    #   # 0x1f0d000:      0x0000000000000000      0x0000000000002011
    #   # 0x1f0d010:      0x00007f892a9f87b8      0x00007f892a9f87b8
    #   # 0x1f0d020:      0x0000000000000000      0x0000000000000000
    #   # 0x1f0d030:      0x0000000000000000      0x0000000000000000
    # @example
    #   h.x 3, 0x400000
    #   # 0x400000:       0x00010102464c457f      0x0000000000000000
    #   # 0x400010:       0x00000001003e0002
    def x(count, address)
      return unless load?
      dumper.x(count, address)
    end

    # Gdb-like command.
    #
    # Search a specific value/string/regexp in memory.
    # @param [Integer, String, Regexp] pattern
    #   The desired search pattern, can be value(+Integer+), string, or regular expression.
    # @param [Integer, String, Symbol] from
    #   Start address for searching, can be segment(+Symbol+) or segments with offset.
    #   See examples for more information.
    # @param [Integer] length
    #   The search length limit, default is unlimited,
    #   which will search until pattern found or reach unreadable memory.
    # @return [Integer, NilClass] The first matched address, +nil+ is returned when no such pattern found.
    # @example
    #   h.find(0xdeadbeef, 'heap+0x10', 0x1000)
    #   # => 6299664 # 0x602010
    #   h.find(/E.F/, 0x400000, 4)
    #   # => 4194305 # 0x400001
    #   h.find(/E.F/, 0x400000, 3)
    #   # => nil
    #   sh_offset = h.find('/bin/sh', :libc) - h.libc.base
    #   # => 1559771 # 0x17ccdb
    def find(pattern, from, length = :unlimited)
      return Nil.new unless load?
      length = 1 << 40 if length.is_a? Symbol
      dumper.find(pattern, from, length)
    end

    # +search+ is more intutive to me
    alias search find

    # Pretty dump of bins layouts.
    #
    # The request layouts will output to +stdout+.
    # @param [Array<Symbol>] args Bin type(s) you want to see.
    # @return [void]
    # @example
    #   h.layouts(:fast, :unsorted, :small)
    def layouts(*args)
      return unless load?
      puts libc.main_arena.layouts(*args)
    end

    # Show simple information of target process.
    # Contains program names, pid, and segments' info.
    #
    # @return [String]
    # @example
    #   puts h
    def to_s
      return 'Process not found' unless load?
      "Program: #{Helper.color program.name} PID: #{Helper.color pid}\n" +
        program.to_s +
        heap.to_s +
        stack.to_s +
        libc.to_s +
        ld.to_s
    end

    private

    attr_accessor :dumper
    def load?
      @pid != nil
    end

    def load! # try to load
      return true if @pid
      @pid = fetch_pid
      return clear_process if @pid.nil? # still can't load
      load_info!
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

    def clear_process
      ProcessInfo::EXPORT.each do |m|
        self.class.send(:define_method, m) { Nil.new }
      end
      false
    end

    def load_info! # :nodoc:
      @info = ProcessInfo.new(self)
      ProcessInfo::EXPORT.each do |m|
        self.class.send(:define_method, m) { @info.send(m) }
      end
      @dumper = Dumper.new(mem_filename) do |sym|
        @info.send(sym) if @info.respond_to?(sym)
      end
    end

    def mem_filename
      "/proc/#{pid}/mem"
    end
  end
end
