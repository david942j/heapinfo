module HeapInfo
  # Class for memory dump relation works
  class Dumper
    # Default dump length
    DUMP_BYTES = 8

    # Instantiate a {HeapInfo::Dumper} object
    #
    # @param [HeapInfo::ProcessInfo] info process info object.
    # @param [String] mem_filename The filename that can be access for dump. Should be +/proc/[pid]/mem+.
    def initialize(info, mem_filename)
      @info = info
      @filename = mem_filename
      need_permission unless dumpable?
    end

    # A helper for {HeapInfo::Process} to dump memory.
    # @param [Mixed] args The use input commands, see examples of {HeapInfo::Process#dump}.
    # @return [String, NilClass] Dump results. If error happend, +nil+ is returned.
    # @example
    #   p dump(:elf, 4)
    #   # => "\x7fELF"
    def dump(*args)
      return need_permission unless dumpable?
      base, len = base_len_of(*args)
      file = mem_f
      file.pos = base
      mem = file.readpartial len
      file.close
      mem
    rescue => e
      raise e if e.is_a? ArgumentError
      nil
    end

    # Return the dump result as chunks.
    # see {HeapInfo::Chunks} and {HeapInfo::Chunk} for more information.
    #
    # Note: Same as {#dump}, need permission of attaching another process.
    # @return [HeapInfo::Chunks] An array of chunk(s).
    # @param [Mixed] args Same as arguments of {#dump}.
    def dump_chunks(*args)
      base = base_of(*args)
      dump(*args).to_chunks(bits: @info.bits, base: base)
    end

    # Show dump results like in gdb's command +x+.
    #
    # Details are in {HeapInfo:Process#x}.
    # @param [Integer] count The number of result need to dump.
    # @param [Mixed] commands Same format as +#dump(*args)+.
    # @return [void]
    # @example
    #   x 3, 0x400000
    #   # 0x400000:       0x00010102464c457f      0x0000000000000000
    #   # 0x400010:       0x00000001003e0002
    def x(count, *commands)
      commands += [count * size_t]
      base = base_of(*commands)
      res = dump(*commands).unpack(size_t == 4 ? 'L*' : 'Q*')
      str = res.group_by.with_index { |_, i| i / (16 / size_t) }.map do |round, values|
        format("%#x:\t", (base + round * 16)) +
          values.map { |v| Helper.color(format("0x%0#{size_t * 2}x", v)) }.join("\t")
      end.join("\n")
      puts str
    end

    # Search a specific value/string/regexp in memory.
    # +#find+ only return the first matched address.
    # @param [Integer, String, Regexp] pattern
    #   The desired search pattern, can be value(+Integer+), string, or regular expression.
    # @param [Integer, String, Symbol] from
    #   Start address for searching, can be segment(+Symbol+)
    #   or segments with offset. See examples for more information.
    # @param [Integer] length The length limit for searching.
    # @return [Integer, NilClass] The first matched address, +nil+ is returned when no such pattern found.
    # @example
    #   find(/E.F/, :elf)
    #   # => 4194305
    #   find(0x4141414141414141, 'heap+0x10', 0x1000)
    #   # => 6291472
    #   find('/bin/sh', :libc)
    #   # => 140662379588827
    def find(pattern, from, length)
      from = base_of(from)
      length = 1 << 40 if length.is_a? Symbol
      case pattern
      when Integer then find_integer(pattern, from, length)
      when String then find_string(pattern, from, length)
      when Regexp then find_regexp(pattern, from, length)
      end
    end

    # Parse the dump command into +[base, offset, length]+
    # @param [Array] args The command, see examples for more information
    # @return [Array<Symbol, Integer>]
    #   +[base, offset, length]+, while +base+ can be a +Symbol+ or an +Integer+.
    #   +length+ has default value equals to +8+.
    # @example
    #   HeapInfo::Dumper.parse_cmd([:heap, 32, 10])
    #   # [:heap, 32, 10]
    #   HeapInfo::Dumper.parse_cmd(['heap+0x10, 10'])
    #   # [:heap, 16, 10]
    #   HeapInfo::Dumper.parse_cmd(['heap+0x10'])
    #   # [:heap, 16, 8]
    #   HeapInfo::Dumper.parse_cmd([0x400000, 4])
    #   # [0x400000, 0, 4]
    def self.parse_cmd(args)
      args = split_cmd args
      return :fail unless args.size == 3
      len = args[2].nil? ? DUMP_BYTES : Integer(args[2])
      offset = Integer(args[1])
      base = args[0]
      base = Helper.integer?(base) ? Integer(base) : base.delete(':').to_sym
      [base, offset, len]
    end

    # Helper for +#parse_cmd+.
    #
    # Split commands to exactly three parts: +[base, offset, length]+.
    # +length+ is +nil+ if not present.
    # @param [Array] args
    # @return [Array<String>] +[base, offset, length]+ in string expression.
    # @example
    #   HeapInfo::Dumper.split_cmd([:heap, 32, 10])
    #   # ['heap', '32', '10']
    #   HeapInfo::Dumper.split_cmd([':heap+0x10, 10'])
    #   # [':heap', '0x10', '10']
    #   HeapInfo::Dumper.split_cmd([':heap+0x10'])
    #   # [':heap', '0x10', nil]
    #   HeapInfo::Dumper.split_cmd([0x400000, 4])
    #   # ['4194304', 0, '4']
    def self.split_cmd(args)
      args = args.join(',').delete(' ').split(',').reject(&:empty?) # 'heap, 100', 32 => 'heap', '100', '32'
      return [] if args.empty?
      if args[0].include? '+' # 'heap+0x1'
        args.unshift(*args.shift.split('+', 2))
      elsif args.size <= 2 # no offset given
        args.insert(1, 0)
      end
      args << nil if args.size <= 2 # no length given
      args[0, 3]
    end

    private

    def need_permission
      msg = 'Could not attach to process. ' \
            'Check the setting of /proc/sys/kernel/yama/ptrace_scope, ' \
            'or try again as the root user. ' \
            'For more details, see /etc/sysctl.d/10-ptrace.conf'
      puts Helper.color(msg, sev: :fatal)
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

    def mem_f
      File.open(@filename)
    end

    def base_len_of(*args)
      base, offset, len = Dumper.parse_cmd(args)
      if HeapInfo::ProcessInfo::EXPORT.include?(base) && (segment = @info.send(base)).is_a?(Segment)
        base = segment.base
      elsif !base.is_a?(Integer)
        raise ArgumentError, "Invalid base: #{base}" # invalid usage
      end
      [base + offset, len]
    end

    def base_of(*args)
      base_len_of(*args)[0]
    end

    def find_integer(value, from, length)
      find_string([value].pack(size_t == 4 ? 'L*' : 'Q*'), from, length)
    end

    def find_string(string, from, length)
      batch_dumper(from, length) { |str| str.index(string) }
    end

    def find_regexp(pattern, from, length)
      batch_dumper(from, length) { |str| str =~ pattern }
    end

    def batch_dumper(from, remain_size)
      page_size = 0x1000
      while remain_size > 0
        dump_size = [remain_size, page_size].min
        str = dump(from, dump_size)
        break if str.nil? # unreadable
        break unless (idx = yield(str)).nil?
        break if str.length < dump_size # remain is unreadable
        remain_size -= str.length
        from += str.length
      end
      return if idx.nil?
      from + idx
    end

    def size_t
      @info.bits / 8
    end
  end
end
