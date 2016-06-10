module HeapInfo
  module Dumper
    # Default dump length
    DUMP_BYTES = 8
    
    # A helper for <tt>HeapInfo::Process</tt> to dump memory.
    # @param [Hash] segments With values of <tt>HeapInfo::Segment</tt>
    # @param [File] file The memory file, i.e. <tt>/proc/[pid]/mem</tt>
    # @param [Mixed] args The use input commands, see examples of <tt>HeapInfo::Process#dump</tt>
    # @return [String, NilClass] Dump results. If error happend, <tt>nil</tt> is returned.
    def self.dump(segments, file, *args)
      base, offset, len = parse_cmd(args)
      if base.instance_of?(Symbol) and segments[base].instance_of?(Segment)
        addr = segments[base].base
      elsif base.is_a? Integer
        addr = base
      else
        throw
      end
      file.pos = addr + offset
      file.read len
    rescue
      nil
    end

    # Parse the dump command into <tt>[base, offset, length]</tt>
    # @param [Array] args The command, see examples for more information
    # @return [Array] <tt>[base, offset, length]</tt>, while <tt>base</tt> can be a [Symbol] or a [Fixnum]
    # @example
    #   HeapInfo::Dumper::parse_cmd([:heap, 32, 10])
    #   # [:heap, 32, 10]
    #   HeapInfo::Dumper::parse_cmd(['heap+0x10, 10'])
    #   # [:heap, 16, 10]
    #   HeapInfo::Dumper::parse_cmd([0x400000, 4])
    #   # [0x400000, 0, 4]
    def self.parse_cmd(args)
      args = self.split_cmd args
      return :fail unless args.size.between? 2, 3
      len = args.size == 2 ? DUMP_BYTES : Integer(args[-1])
      offset = Integer(args[1])
      base = args[0]
      base = base.delete(':').to_sym if base.is_a? String
      [base, offset, len]
    end

    # Helper for <tt>#parse_cmd</tt>.
    #
    # Split command if it present as a string.
    # Insert <tt>offset=0</tt> if <tt>offset</tt> is not given.
    # @param [Array] args
    # @example
    #   HeapInfo::Dumper::split_cmd([:heap, 32, 10])
    #   # [:heap, 32, 10]
    #   HeapInfo::Dumper::split_cmd(['heap+0x10, 10'])
    #   # ['heap', '0x10', '10']
    #   HeapInfo::Dumper::split_cmd([0x400000, 4])
    #   # [0x400000, 0, 4]
    def self.split_cmd(args)
      if args[0].is_a? String # 'heap+100, 32'
        args = args[0].split(/[\+, ]/).reject(&:empty?) + args[1..-1]
      end
      return [] if args.empty?
      args.insert(1, 0) if args.size <= 2
      args
    end
  end
end
