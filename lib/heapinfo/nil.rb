module HeapInfo
  # Self defined <tt>nil</tt> like class.
  #
  # Be the return values of <tt>#dump</tt> or <tt>#dump_chunks</tt>, to prevent use the return value for calculating accidentally while exploiting remote.
  class Nil
    %i(nil? inspect to_s).each do |method_sym|
      define_method(method_sym){|*args, &block| nil.send(method_sym, *args, &block)}
    end

    # Hook all missing methods
    # @return [HeapInfo::Nil] return <tt>self</tt> so that it can be a <tt>nil</tt> chain.
    # @example
    #   # h.dump would return Nil when process not found
    #   p h.dump(:heap)[8,8].unpack("Q*)
    #   # => nil
    def method_missing(method_sym, *args, &block)
      return nil.send(method_sym, *args, &block) if nil.respond_to? method_sym
      self
    end

    # To prevent error raised when using <tt>puts Nil.new</tt>
    # @return [Array] Empty array
    def to_ary
      []
    end
  end
end
