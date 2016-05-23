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
    %w(status exe maps).each do |method|
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

    # wrapper color for pretty inspect
    def self.color(s, sev: nil)
      s = s.to_s
      if sev == :fatal
        return "\e[38;5;197m#{s}\e[0m"
      end
      if s =~ /^(0x)?[0-9a-f]+$/ # integers
        "\e[38;5;12m#{s}\e[0m"
      else #normal string
        "\e[38;5;1m#{s}\e[0m"
      end
    end
  end
end
