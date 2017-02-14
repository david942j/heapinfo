module HeapInfo
  # Self define a +nil+ like class.
  #
  # Can be the return value of {HeapInfo::Process#dump} and {HeapInfo::Process#dump_chunks},
  # to prevent use the return value for calculating accidentally while exploiting remote.
  class Nil
    %i(nil? inspect to_s).each do |method_sym|
      define_method(method_sym) { |*args, &block| nil.send(method_sym, *args, &block) }
    end

    # Hook all missing methods
    # @return [HeapInfo::Nil] return +self+ so that it can be a +nil+ chain.
    # @example
    #   # h.dump would return Nil when process not found
    #   p h.dump(:heap)[8, 8].unpack('Q*')
    #   # => nil
    def method_missing(method_sym, *args, &block)
      return nil.send(method_sym, *args, &block) if nil.respond_to?(method_sym)
      self || super
    end

    # Yap
    def respond_to_missing?(*)
      super
    end

    # To prevent error raised when using +puts Nil.new+.
    # @return [Array] Empty array
    def to_ary
      []
    end
  end
end
