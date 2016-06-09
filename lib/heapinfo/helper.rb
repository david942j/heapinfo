module HeapInfo
  # Some helper functions
  module Helper
    # Get the process id of a process
    # @param [String] prog The request process name
    # @return [Fixnum] process id
    def self.pidof(prog)
      # plz, don't cmd injection your self :p
      pid = `pidof #{prog}`.strip.to_i
      return nil if pid == 0 # process not exists yet
      throw "pidof #{prog} fail" unless pid.between?(2, 65535)
      pid
      #TODO: handle when multi processes exists
    end

    # Create read <tt>/proc/[pid]/*</tt> methods
    %w(exe maps).each do |method|
      self.define_singleton_method("#{method}_of".to_sym) do |pid|
        begin
          IO.binread("/proc/#{pid}/#{method}")
        rescue
          throw "reading /proc/#{pid}/#{method} error"
        end
      end
    end
    
    # Parse the contents of <tt>/proc/[pid]/maps</tt>.
    #
    # @param [String] content The file content of <tt>/proc/[pid]/maps</tt>
    # @return [Array] In form of <tt>[[start, end, permission, name], ...]</tt>. See examples.
    # @example
    #   HeapInfo::Helper.parse_maps(<<EOS
    #     00400000-0040b000 r-xp 00000000 ca:01 271708                             /bin/cat
    #     00bc4000-00be5000 rw-p 00000000 00:00 0                                  [heap]
    #     7f2788315000-7f2788316000 r--p 00022000 ca:01 402319                     /lib/x86_64-linux-gnu/ld-2.19.so
    #     EOS
    #   )
    #   # [[0x400000, 0x40b000, 'r-xp', '/bin/cat'], 
    #   # [0xbc4000, 0xbe5000, 'rw-p', '[heap]'], 
    #   # [0x7f2788315000, 0x7f2788316000, 'r--p', '/lib/x86_64-linux-gnu/ld-2.19.so']]
    def self.parse_maps(content)
      lines = content.split("\n")
      lines.map do |line|
        s = line.scan(/^([0-9a-f]+)-([0-9a-f]+)\s([rwxp-]{4})[^\/|\[]*([\/|\[].+)$/)[0]
        next nil if s.nil?
        s[0],s[1] = s[0,2].map{|h|h.to_i(16)}
        s
      end.compact
    end

    # Color codes for pretty print
    COLOR_CODE = {
      esc_m: "\e[0m",
      normal_s: "\e[38;5;1m", # red
      integer: "\e[38;5;12m", # light blue
      fatal: "\e[38;5;197m", # dark red
      bin: "\e[38;5;120m", # light green
      klass: "\e[38;5;155m", # pry like
      sym: "\e[38;5;229m", # pry like
    }
    # Wrapper color codes for for pretty inspect
    # @param [String] s Contents for wrapper
    # @param [Symbol?] sev Specific which kind of color want to use, valid symbols are defined in <tt>#COLOR_CODE</tt>.
    # If this argument is not present, will detect according to the content of <tt>s</tt>
    # @return [String] wrapper with color codes. 
    def self.color(s, sev: nil)
      s = s.to_s
      color = ''
      cc = COLOR_CODE
      if cc.keys.include?(sev)
        color = cc[sev]
      elsif s =~ /^(0x)?[0-9a-f]+$/ # integers
        color = cc[:integer]
      else #normal string
        color = cc[:normal_s]
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
    def self.unpack(size_t, data)
      data.unpack(size_t == 4 ? 'L*' : 'Q*')[0]
    end
  end
end
