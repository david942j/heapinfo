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
    %w(status exe).each do |method|
      self.define_singleton_method("#{method}_of".to_sym) do |pid|
        begin
          IO.binread("/proc/#{pid}/#{method}")
        rescue
          throw "reading /proc/#{pid}/#{method} error"
        end
      end
    end
  end
end
