# frozen_string_literal: true

require 'dentaku'
require 'shellwords'
require 'time'
require 'tmpdir'

module HeapInfo
  # Some helper functions.
  module Helper
    module_function

    # @!macro proc_content_doc
    #   @param [Integer] pid The process id.
    #   @return [String] The file content.
    # @!method auxv_of(pid)
    #   Fetch the content of /proc/+pid+/auxv.
    #   @macro proc_content_doc
    # @!method exe_of(pid)
    #   Fetch the content of /proc/+pid+/exe.
    #   @macro proc_content_doc
    # @!method maps_of(pid)
    #   Fetch the content of /proc/+pid+/maps.
    #   @macro proc_content_doc

    # Create read +/proc/[pid]/*+ methods.
    %w[exe maps auxv].each do |method|
      define_singleton_method("#{method}_of".to_sym) do |pid|
        begin
          IO.binread("/proc/#{pid}/#{method}")
        rescue Errno::ENOENT
          throw "reading /proc/#{pid}/#{method} error"
        end
      end
    end

    # Get the process id from program name.
    #
    # When multiple processes exist, the one with lastest start time would be returned.
    # @param [String] prog The request process name.
    # @return [Integer] Process id.
    def pidof(prog)
      info = %x(ps -o pid=,lstart= --pid `pidof #{Shellwords.escape(prog)}` 2>/dev/null).lines.map do |l|
        pid, time = l.split(' ', 2)
        [Time.parse(time), pid.to_i]
      end
      return nil if info.empty? # process not exists yet

      info.max_by(&:first).last
    end

    # Parse the contents of <tt>/proc/[pid]/maps</tt>.
    #
    # @param [String] content The file content of <tt>/proc/[pid]/maps</tt>.
    # @return [Array] In form of <tt>[[start, end, permission, name], ...]</tt>. See examples.
    # @example
    #   HeapInfo::Helper.parse_maps(<<-EOS)
    #     00400000-0040b000 r-xp 00000000 ca:01 271708                             /bin/cat
    #     00bc4000-00be5000 rw-p 00000000 00:00 0                                  [heap]
    #     7f2788315000-7f2788316000 r--p 00022000 ca:01 402319                     /lib/x86_64-linux-gnu/ld-2.19.so
    #   EOS
    #   # [[0x400000, 0x40b000, 'r-xp', '/bin/cat'],
    #   # [0xbc4000, 0xbe5000, 'rw-p', '[heap]'],
    #   # [0x7f2788315000, 0x7f2788316000, 'r--p', '/lib/x86_64-linux-gnu/ld-2.19.so']]
    def parse_maps(content)
      lines = content.split("\n")
      lines.map do |line|
        s = line.scan(%r{^([0-9a-f]+)-([0-9a-f]+)\s([rwxp-]{4})[^/|\[]*([/|\[].+)?$})[0]
        next nil if s.nil?

        s[0], s[1] = s[0, 2].map { |h| h.to_i(16) }
        s[3] ||= '' # some segments don't have a name
        s
      end.compact
    end

    # Combines {.parse_maps} and {.maps_of}.
    #
    # @param [Integer] pid
    #
    # @return [Array]
    #   The same return type as {.parse_maps}'s.
    #
    # @see .parse_maps
    def parsed_maps(pid)
      parse_maps(maps_of(pid))
    end

    # enable / disable the color function.
    # @param [Boolean] on Enable or not.
    # @return [void]
    def toggle_color(on: false)
      @disable_color = !on
    end

    # Color codes for pretty print.
    COLOR_CODE = {
      esc_m: "\e[0m",
      normal_s: "\e[38;5;209m", # red
      integer: "\e[38;5;153m", # light blue
      fatal: "\e[38;5;197m", # dark red
      bin: "\e[38;5;120m", # light green
      klass: "\e[38;5;155m",
      sym: "\e[38;5;230m"
    }.freeze
    # Wrapper color codes for pretty inspect.
    # @param [String] s Contents for wrapper.
    # @param [Symbol?] sev
    #   Specific which kind of color want to use, valid symbols are defined in +#COLOR_CODE+.
    #   If this argument is not present, will detect according to the content of +s+.
    # @return [String] wrapper with color codes.
    def color(s, sev: nil)
      s = s.to_s
      return s if @disable_color

      cc = COLOR_CODE
      color = if cc.key?(sev) then cc[sev]
              elsif integer?(s) then cc[:integer] # integers
              else cc[:normal_s] # normal string
              end
      "#{color}#{s.sub(cc[:esc_m], color)}#{cc[:esc_m]}"
    end

    # Unpack strings to integer.
    #
    # Like the <tt>p32</tt> and <tt>p64</tt> in pwntools.
    #
    # @param [Integer] size_t Either 4 or 8.
    # @param [String] data String to be unpack.
    # @return [Integer] Unpacked result.
    # @example
    #   HeapInfo::Helper.unpack(4, "\x12\x34\x56\x78")
    #   # 0x78563412
    #   HeapInfo::Helper.unpack(8, "\x12\x34\x56\x78\xfe\xeb\x90\x90")
    #   # 0x9090ebfe78563412
    def unpack(size_t, data)
      data.unpack(size_t == 4 ? 'L*' : 'Q*')[0]
    end

    # Convert number in hex format.
    #
    # @param [Integer] num An integer.
    # @return [String] number in hex format.
    # @example
    #   HeapInfo::Helper.hex(1000) #=> '0x3e8'
    def hex(num)
      return format('0x%x', num) if num >= 0

      format('-0x%x', -num)
    end

    # Combines {.hex} and {.color}.
    #
    # @param [Integer] num
    #   An integer.
    #
    # @return [String]
    #   Returns hex string wrapped with color code.
    def color_hex(num)
      color(hex(num))
    end

    # Retrieve pure class name(without module) of an object.
    # @param [Object] obj Any instance.
    # @return [String] Class name of +obj+.
    # @example
    #   # suppose obj is an instance of HeapInfo::Chunk
    #   Helper.class_name(obj)
    #   #=> 'Chunk'
    def class_name(obj)
      obj.class.name.split('::').last || obj.class.name
    end

    # For checking a string is actually an integer.
    # @param [String] str String to be checked.
    # @return [Boolean] If +str+ can be converted into integer.
    # @example
    #   Helper.integer? '1234'
    #   #=> true
    #   Helper.integer? '0x1234'
    #   #=> true
    #   Helper.integer? '0xheapoverflow'
    #   #=> false
    def integer?(str)
      true if Integer(str)
    rescue ArgumentError, TypeError
      false
    end

    # Safe-eval using dentaku.
    # @param [String] formula Formula to be eval.
    # @param [Hash{Symbol => Integer}] store Predefined values.
    # @return [Integer] Evaluate result.
    def evaluate(formula, store: {})
      calc = Dentaku::Calculator.new
      formula = formula.delete(':')
      calc.store(store).evaluate(formula)
    end

    # Get temp filename.
    # @param [String] name Filename.
    # @return [String] Temp filename.
    def tempfile(name)
      Dir::Tmpname.create(name, HeapInfo::TMP_DIR) {}
    end
  end
end
