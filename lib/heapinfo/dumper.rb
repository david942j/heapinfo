module HeapInfo
  module Dumper
    DUMP_BYTES = 8
    # @params: segments, mem_file, options
    def self.dump(*args)
      segments = args.shift
      file = args.shift
      base, offset, len = parse_cmd(args)
      if base.instance_of?(Symbol) and segments[base].instance_of?(Segment)
        addr = segments[base].base
      elsif base.is_a? Integer
        addr = base
      else
        throw "dump #{args} not valid"
      end
      file.pos = addr + offset
      file.read len
    rescue
      nil
    end

    def self.parse_cmd(args)
      args = self.split_cmd args
      return :fail unless args.size.between? 2, 3
      len = args.size == 2 ? DUMP_BYTES : Integer(args[-1])
      offset = Integer(args[1])
      base = args[0]
      base = base.to_sym if base.is_a? String
      [base, offset, len]
    end

    # split cmd if it present as a string
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
