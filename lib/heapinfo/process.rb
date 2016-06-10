#encoding: ascii-8bit
module HeapInfo
  # Main class of heapinfo.
  class Process
    # The dafault options of libaries,
    # use for matching glibc and ld segments in <tt>/proc/[pid]/maps</tt>
    DEFAULT_LIB = {
      libc: /libc[^\w]/,
      ld:   /\/ld-.+\.so/,
    }
    # @return [Fixnum, NilClass] return the pid of process, <tt>nil</tt> if no such process found
    attr_reader :pid
    attr_reader :status

    # Instantiate a <tt>HeapInfo::Process</tt> object
    # @param [String, Fixnum] prog Process name or pid, see <tt>HeapInfo::heapinfo</tt> for more information
    # @param [Hash] options libraries' filename, see <tt>HeapInfo::heapinfo</tt> for more information
    def initialize(prog, options = {})
      @prog = prog
      @options = DEFAULT_LIB.merge options
      load!
      return unless load?
      need_permission unless dumpable?
    end

    # Use this method to wrapper all HeapInfo methods.
    #
    # Since <tt>::HeapInfo</tt> is a tool(debugger) for local usage, 
    # while exploiting remote service, all methods will not work properly.
    # So I suggest to wrapper all methods inside <tt>#debug</tt>,
    # which will ignore the block while the victim process is not found.
    #
    # @example
    #   h = heapinfo('./victim') # such process is not exist
    #   libc_base = leak_libc_base_of_victim # normal exploit
    #   h.debug {
    #     # for local to check if exploit correct
    #     fail('libc_base') unless libc_base == h.libc.base
    #   }
    #   # block of #debug will not execute if h.pid is nil
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
    #   dump(:heap) # &heap[0, 8]
    #   dump(:heap, 64) # &heap[0, 64]
    #   dump(:heap, 256, 64) # &heap[256, 64]
    #   dump('heap+256, 64'  # &heap[256, 64]
    #   dump('heap+0x100', 64) # &heap[256, 64]
    #   dump(<segment>, 8) # semgent can be [heap, stack, (program|elf), libc, ld]
    #   dump(addr, 64) # addr[0, 64]
    #
    #   # Invalid usage
    #   dump(:meow) # no such segment
    #   dump('heap-1, 64') # not support '-'
    def dump(*args)
      return Nil.new unless load?
      return need_permission unless dumpable?
      mem = Dumper.dump(@status, f = mem_f, *args)
      f.close
      mem
    end

    # Return the dump result as chunks.
    # see <tt>HeapInfo::Chunks</tt> and <tt>HeapInfo::Chunk</tt> for more information.
    #
    # Note: Same as <tt>dump</tt>, need permission of attaching another process.
    # @return [HeapInfo::Chunks, HeapInfo::Nil] An array of chunk(s).
    # @param [Mixed] args Same arguments of <tt>#dump</tt>
    def dump_chunks(*args)
      return Nil.new unless load?
      return need_permission unless dumpable?
      base = base_of_dump_commands(*args)
      dump(*args).to_chunks(bits: @status[:bits], base: base)
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
      commands = commands + [count * size_t]
      base = base_of_dump_commands(*commands)
      res = dump(*commands).unpack(size_t == 4 ? "L*" : "Q*")
      str = res.group_by.with_index{|_, i| i / (16 / size_t) }.map do |round, values|
        "%#x:\t" % (base + round * 16) + values.map{|v| Helper.color "0x%0#{size_t * 2}x" % v}.join("\t")
      end.join("\n")
      io.puts str
    end

    # Gdb-like command.
    #
    # Search a specific value/string/regexp in memory.
    # <tt>#find</tt> only return the first matched address, if want to find all adress, use <tt>#find_all</tt> instead.
    # @param [Integer, String, Regexp] pattern The desired search pattern, can be value(<tt>Integer</tt>), string, or regular expression.
    # @param [Integer, String, Symbol] from Start address for searching, can be segment(<tt>Symbol</tt>) or segments with offset. See examples for more information.
    # @param [Integer] length The search length limit, default is unlimited, which will search until pattern found or reach unreadable memory.
    # @return [Integer, NilClass] The first matched address, <tt>nil</tt> is returned when no such pattern found.
    # @example
    #   h.find(0xdeadbeef, :heap)
    #   h.find(0xdeadbeef, 'heap+0x10', 0x1000)
    def find(pattern, from, length = :unlimited)
      return Nil.new unless load?
      from = base_of_dump_commands(from)
      length = 1 << 40 if length.is_a? Symbol
      return find_regexp(pattern, from, length) if pattern.is_a? Regexp
      return find_string(pattern, from, length) if pattern.is_a? String
      return find_integer(pattern, from, length) if pattern.is_a? Integer
      nil
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
        bits:    bits_of(elf),
      }
      @status[:elf] = @status[:program] #alias
      @status.keys.each do |m|
        self.class.send(:define_method, m) {@status[m]}
      end
    end
    def match_maps(maps, pattern)
      maps.map{|s| s[3]}.find{|seg| pattern.is_a?(Regexp) ? seg =~ pattern : seg.include?(pattern)}
    end
    def bits_of(elf)
      elf[4] == "\x01" ? 32 : 64
    end
    def size_t
      @status[:bits] / 8
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
    def base_of_dump_commands(*args)
      base, offset, _ = Dumper.parse_cmd(args)
      base = @status[base].base if @status[base].is_a? Segment
      base + offset
    end
    def find_integer(value, from, length)
      find_string([value].pack(size_t == 4 ? "L*" : "Q*"), from, length)
    end
    def find_string(string, from ,length)
      batch_dumper(from, length) {|str| str.index string}
    end
    def find_regexp(pattern, from ,length)
      batch_dumper(from, length) {|str| str =~ pattern}
    end
    def batch_dumper(from, remain_size)
      page_size = 0x1000
      while remain_size > 0
        dump_size = [remain_size, page_size].min
        str = self.dump(from, dump_size)
        break if str.nil? # unreadable
        break unless (idx = yield(str)).nil?
        break if str.length < dump_size # remain is unreadable
        remain_size -= str.length
        from += str.length
      end
      return if idx.nil?
      from + idx
    end
  end
end
