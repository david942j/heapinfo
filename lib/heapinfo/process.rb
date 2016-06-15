#encoding: ascii-8bit
module HeapInfo
  # Main class of heapinfo.
  class Process
    # The default options of libaries,
    # use for matching glibc and ld segments in <tt>/proc/[pid]/maps</tt>
    DEFAULT_LIB = {
      libc: /libc[^\w]/,
      ld:   /\/ld-.+\.so/,
    }
    # @return [Fixnum, NilClass] return the pid of process, <tt>nil</tt> if no such process found
    attr_reader :pid

    # Instantiate a <tt>HeapInfo::Process</tt> object
    # @param [String, Fixnum] prog Process name or pid, see <tt>HeapInfo::heapinfo</tt> for more information
    # @param [Hash] options libraries' filename, see <tt>HeapInfo::heapinfo</tt> for more information
    def initialize(prog, options = {})
      @prog = prog
      @options = DEFAULT_LIB.merge options
      load!
      return unless load?
    end

    # Use this method to wrapper all HeapInfo methods.
    #
    # Since <tt>::HeapInfo</tt> is a tool(debugger) for local usage, 
    # while exploiting remote service, all methods will not work properly.
    # So I suggest to wrapper all methods inside <tt>#debug</tt>,
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
    # Note: This method require you have permission of attaching another process. If not, a warning message will present.
    #
    # @param [Mixed] args Will be parsed into <tt>[base, offset, length]</tt>, see Examples for more information.
    # @return [String, HeapInfo::Nil] The content needed. When the request address is not readable or the process not exists, <tt>HeapInfo::Nil.new</tt> is returned.
    #
    # @example
    #   h = heapinfo('victim')
    #   h.dump(:heap) # &heap[0, 8]
    #   h.dump(:heap, 64) # &heap[0, 64]
    #   h.dump(:heap, 256, 64) # &heap[256, 64]
    #   h.dump('heap+256, 64'  # &heap[256, 64]
    #   h.dump('heap+0x100', 64) # &heap[256, 64]
    #   h.dump(<segment>, 8) # semgent can be [heap, stack, (program|elf), libc, ld]
    #   h.dump(addr, 64) # addr[0, 64]
    #
    #   # Invalid usage
    #   dump(:meow) # no such segment
    #   dump('heap-1, 64') # not support '-'
    def dump(*args)
      return Nil.new unless load?
      dumper.dump(*args)
    end

    # Return the dump result as chunks.
    # see <tt>HeapInfo::Dumper#dump_chunks</tt> for more information.
    #
    # @return [HeapInfo::Chunks, HeapInfo::Nil] An array of chunk(s).
    # @param [Mixed] args Same as arguments of <tt>#dump</tt>
    def dump_chunks(*args)
      return Nil.new unless load?
      dumper.dump_chunks(*args)
    end

    # Gdb-like command
    #
    # Show dump results like in gdb's command <tt>x</tt>,
    # while will auto detect the current elf class to decide using <tt>gx</tt> or <tt>wx</tt>.
    #
    # The dump results wrapper with color codes and nice typesetting will output to <tt>stdout</tt> by default.
    # @param [Integer] count The number of result need to dump, see examples for more information
    # @param [Mixed] commands Same format as <tt>#dump(*args)</tt>, see <tt>#dump</tt> for more information
    # @param [IO] io <tt>IO</tt> that use for printing, default is <tt>$stdout</tt>
    # @return [NilClass] The return value of <tt>io.puts</tt>.
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
    def x(count, *commands, io: $stdout)
      return unless load? and io.respond_to? :puts
      dumper.x(count, *commands, io: io)
    end

    # Gdb-like command.
    #
    # Search a specific value/string/regexp in memory.
    # @param [Integer, String, Regexp] pattern The desired search pattern, can be value(<tt>Integer</tt>), string, or regular expression.
    # @param [Integer, String, Symbol] from Start address for searching, can be segment(<tt>Symbol</tt>) or segments with offset. See examples for more information.
    # @param [Integer] length The search length limit, default is unlimited, which will search until pattern found or reach unreadable memory.
    # @return [Integer, NilClass] The first matched address, <tt>nil</tt> is returned when no such pattern found.
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

    # <tt>search</tt> is more intutive to me
    alias :search :find

    # Pretty dump of bins layouts.
    #
    # The request layouts will output to <tt>stdout</tt> by default.
    # @param [Array<Symbol>] args Bin type(s) you want to see.
    # @param [IO] io <tt>IO</tt> that use for printing, default is <tt>$stdout</tt>
    # @return [NilClass] The return value of <tt>io.puts</tt>.
    # @example
    #   h.layouts :fastbin, :unsorted_bin, :smallbin
    def layouts(*args, io: $stdout)
      return unless load? and io.respond_to? :puts
      io.puts self.libc.main_arena.layouts(*args)
    end

    # Show simple information of target process.
    # Contains program names, pid, and segments' info.
    #
    # @return [String]
    # @example
    #   puts h
    def to_s
      return "Process not found" unless load?
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
      return if @pid
      @pid = fetch_pid
      return false if @pid.nil? # still can't load
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

    def load_info!
      @info = ProcessInfo.new(self)
      ProcessInfo::EXPORT.each do |m|
        self.class.send(:define_method, m) {@info.send(m)}
      end
      @dumper = Dumper.new(@info, mem_filename)
    end
    def mem_filename
      "/proc/#{pid}/mem"
    end
  end
end
