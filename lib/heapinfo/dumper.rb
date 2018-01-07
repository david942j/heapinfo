module HeapInfo
  # Class for memory dump relation works
  class Dumper
    # Default dump length
    DUMP_BYTES = 8

    # Instantiate a {HeapInfo::Dumper} object
    #
    # @param [String] mem_filename The filename that can be access for dump. Should be +/proc/[pid]/mem+.
    # @param [Proc] block
    #   Use for get segment info.
    #   See {Dumper#base_len_of} for more information.
    def initialize(mem_filename, &block)
      @filename = mem_filename
      @info = block || ->(*) { HeapInfo::Nil.new }
      need_permission unless dumpable?
    end

    # A helper for {HeapInfo::Process} to dump memory.
    # @param [Mixed] args The use input commands, see examples of {HeapInfo::Process#dump}.
    # @return [String, nil] Dump results. If error happend, +nil+ is returned.
    # @example
    #   p dump(:elf, 4)
    #   #=> "\x7fELF"
    def dump(*args)
      return need_permission unless dumpable?
      base, len = base_len_of(*args)
      file = mem_f
      file.pos = base
      mem = file.readpartial len
      file.close
      mem
    rescue => e # rubocop:disable Lint/RescueWithoutErrorClass
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
      dump(*args).to_chunks(bits: @info[:bits], base: base)
    end

    # Show dump results like in gdb's command +x+.
    #
    # Details are in {HeapInfo::Process#x}.
    # @param [Integer] count The number of result need to dump.
    # @param [Symbol, String, Integer] address The base address to be dumped.
    # @return [void]
    # @example
    #   x 3, 0x400000
    #   # 0x400000:       0x00010102464c457f      0x0000000000000000
    #   # 0x400010:       0x00000001003e0002
    def x(count, address)
      commands = [address, count * size_t]
      base = base_of(*commands)
      res = dump(*commands).unpack(size_t == 4 ? 'L*' : 'Q*')
      str = res.group_by.with_index { |_, i| i / (16 / size_t) }.map do |round, values|
        Helper.hex(base + round * 16) + ":\t" +
          values.map { |v| Helper.color(format("0x%0#{size_t * 2}x", v)) }.join("\t")
      end.join("\n")
      puts str
    end

    # @api private
    #
    # Search a specific value/string/regexp in memory.
    # +#find+ only return the first matched address.
    # @param [Integer, String, Regexp] pattern
    #   The desired search pattern, can be value(+Integer+), string, or regular expression.
    # @param [Integer, String, Symbol] from
    #   Start address for searching, can be segment(+Symbol+)
    #   or segments with offset. See examples for more information.
    # @param [Integer] length The length limit for searching.
    # @param [Boolean] rel Return relative or absolute.
    # @return [Integer, nil] The first matched address, +nil+ is returned when no such pattern found.
    # @example
    #   find(/E.F/, :elf, false)
    #   #=> 4194305
    #   find(0x4141414141414141, 'heap+0x10', 0x1000, false)
    #   #=> 6291472
    #   find('/bin/sh', :libc, true)
    #   #=> 1622391 # 0x18c177
    def find(pattern, from, length, rel)
      from = base_of(from)
      length = 1 << 40 if length.is_a? Symbol
      ret = case pattern
            when Integer then find_integer(pattern, from, length)
            when String then find_string(pattern, from, length)
            when Regexp then find_regexp(pattern, from, length)
            end
      ret -= from if ret && rel
      ret
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
    rescue Errno::EACCES, Errno::ENOENT
      false
    end

    def mem_f
      File.open(@filename)
    end

    # Get the base address and length.
    #
    # +@info+ will be used for getting the segment base,
    # so we can support use symbol as base address.
    # @param [Integer, Symbol, String] arg The base address, see examples.
    # @param [Integer] len An integer.
    # @example
    #   base_len_of(123, 321) #=> [123, 321]
    #   base_len_of(123) #=> [123, DUMP_BYTES]
    #   base_len_of(:heap, 10) #=> [0x603000, 10] # assume heap base @ 0x603000
    #   base_len_of('heap+0x30', 10) #=> [0x603030, 10]
    #   base_len_of('elf+0x3*2-1') #=> [0x400005, DUMP_BYTES]
    def base_len_of(arg, len = DUMP_BYTES)
      segments = @info.call(:segments) || {}
      segments = segments.each_with_object({}) do |(k, seg), memo|
        memo[k] = seg.base
      end
      base = case arg
             when Integer then arg
             when Symbol then segments[arg]
             when String then Helper.evaluate(arg, store: segments)
             end
      raise ArgumentError, "Invalid base: #{arg.inspect}" unless base.is_a?(Integer) # invalid usage
      [base, len]
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
      @info[:bits] / 8
    end
  end
end
