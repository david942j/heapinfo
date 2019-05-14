# frozen_string_literal: true

require 'singleton'

module HeapInfo
  # Self define a +nil+ like class.
  #
  # Can be the return value of {HeapInfo::Process#dump} and {HeapInfo::Process#dump_chunks},
  # to prevent use the return value for calculating accidentally while exploiting remote.
  class Nil
    include Singleton

    %i[nil? inspect to_s].each do |method_sym|
      define_method(method_sym) { |*args, &block| nil.__send__(method_sym, *args, &block) }
    end

    # Hook all missing methods
    # @return [HeapInfo::Nil] return +self+ so that it can be a +nil+ chain.
    # @example
    #   # h.dump would return Nil when process not found
    #   p h.dump(:heap)[8, 8].unpack('Q*')
    #   #=> nil
    def method_missing(method_sym, *args, &block) # rubocop:disable Style/MethodMissingSuper
      return nil.__send__(method_sym, *args, &block) if nil.respond_to?(method_sym)

      self
    end

    # Yap
    def respond_to_missing?(*)
      super
    end

    # To prevent error raised with +puts Nil.instance+.
    # @return [Array] An empty array.
    def to_ary
      []
    end
  end
end
