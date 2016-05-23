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
    end

  private
    def self.parse_cmd(args)
      return :fail if args.empty?
      if args.size == 1 # 'heap, 100, 32'
        args = args[0].split(/[, ]/).select{|c|not c.empty?}
      end
      return :fail unless args.size.between? 1, 3
      offset = 0
      len = args.size == 1 ? DUMP_BYTES : Integer(args[-1])
      offset = Integer(args[1]) if args.size == 3
      base = args[0]
      if base.respond_to?(:include?) and base.include?('+') # present as 'heap+0x10'
        sp = base.split('+')[0, 2]
        base, offset = sp[0], Integer(sp[1])
      end
      base = base.to_sym if base.is_a? String
      [base, offset, len]
    end
  end
end
