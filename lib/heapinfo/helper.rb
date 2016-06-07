module HeapInfo
  module Helper
    def self.pidof(prog)
      # plz, don't cmd injection your self :p
      pid = `pidof #{prog}`.strip.to_i
      throw "pidof #{prog} fail" unless pid.between?(2, 65535)
      pid
      #TODO: handle when multi processes exists
    end
    # create read /proc/$pid/* methods
    %w(exe maps).each do |method|
      self.define_singleton_method("#{method}_of".to_sym) do |pid|
        begin
          IO.binread("/proc/#{pid}/#{method}")
        rescue
          throw "reading /proc/#{pid}/#{method} error"
        end
      end
    end
    
    # parse lines in /proc/[pid]/maps
    # @params lines: String or Array of String
    # return [[start, end, perm, name], ...]
    def self.parse_maps(lines)
      lines = lines.split("\n") if lines.is_a?(String)
      lines.map do |line|
        s = line.scan(/^([0-9a-f]+)-([0-9a-f]+)\s([rwxp-]{4})[^\/|\[]*([\/|\[].+)$/)[0]
        next nil if s.nil?
        s[0],s[1] = s[0,2].map{|h|h.to_i(16)}
        s
      end.compact
    end

    COLOR_CODE = {
      esc_m: "\e[0m",
      normal_s: "\e[38;5;1m", # red
      integer: "\e[38;5;12m", # light blue
      fatal: "\e[38;5;197m", # dark red
      bin: "\e[38;5;120m", # light green
      klass: "\e[38;5;155m", # pry like
      sym: "\e[38;5;229m", # pry like
    }
    # wrapper color for pretty inspect
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

    def self.unpack(size_t, data)
      data.unpack(size_t == 4 ? 'L*' : 'Q*')[0]
    end
  end
end
