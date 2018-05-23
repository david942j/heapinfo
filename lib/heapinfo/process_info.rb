# encoding: ascii-8bit

require 'stringio'

require 'heapinfo/segment'
require 'heapinfo/libc'
require 'heapinfo/helper'

module HeapInfo
  # For {Process} to record basic process information.
  #
  # {Process} has a +process_info+ object iff the process exists (pid not +nil+).
  # Mainly records segments' base.
  class ProcessInfo
    # Methods to be transparent to +process+.
    # e.g. +process.libc+ alias to +process.info.libc+.
    EXPORT = %i[libc ld heap program elf stack bits auxv].freeze

    # @return [Integer] 32 or 64.
    attr_reader :bits
    # @return [HeapInfo::Segment]
    attr_reader :program
    # @return [HeapInfo::Segment]
    attr_reader :stack
    # @return [HeapInfo::Libc]
    attr_reader :libc
    # @return [HeapInfo::Segment]
    attr_reader :ld
    # @return [Hash{Symbol => Integer}] The parsed auxv hash.
    # @example
    #   auxv
    #   #=> {:ld_base => 4152033280, :random => 4294374299}
    attr_reader :auxv
    alias elf program

    # Instantiate a {ProcessInfo} object.
    #
    # @param [HeapInfo::Process] process Load information from maps/memory for +process+.
    def initialize(process)
      @pid = process.pid
      options = process.instance_variable_get(:@options)
      maps = load_maps
      @bits = bits_of(Helper.exe_of(@pid))
      @program = Segment.find(maps, File.readlink("/proc/#{@pid}/exe"))
      # well.. stack is a strange case because it will grow in runtime..
      # should i detect stack base growing..?
      @stack = Segment.find(maps, '[stack]')
      @auxv = parse_auxv(Helper.auxv_of(@pid))
      ld_seg = maps.find { |m| m[0] == @auxv[:ld_base] } # nil if static-linked elf
      @ld = ld_seg.nil? ? Nil.new : Segment.new(@auxv[:ld_base], ld_seg.last)
      @libc = Libc.find(
        maps, match_maps(maps, options[:libc]),
        bits: @bits,
        ld_name: @ld.name,
        dumper: ->(*args) { process.dump(*args) },
        method_heap: method(:heap)
      )
    end

    # Heap will not be mmapped if the process not use heap yet, so create a lazy loading method.
    # Will re-read maps when heap segment not found yet.
    #
    # Special handling here because heap might not be initialized in the beginning.
    #
    # @return [HeapInfo::Segment] The {Segment} of heap.
    def heap
      @heap ||= Segment.find(load_maps, '[heap]')
    end

    # Return segemnts load currently.
    # @return [Hash{Symbol => Segment}] The segments in hash format.
    def segments
      EXPORT.map do |sym|
        seg = __send__(sym)
        [sym, seg] if seg.is_a?(Segment)
      end.compact.to_h
    end

    def to_segment(sym)
      return nil unless EXPORT.include?(sym)
      seg = __send__(sym)
      return nil unless seg.is_a?(Segment)
      seg
    end

    private

    def load_maps
      Helper.parse_maps(Helper.maps_of(@pid))
    end

    def parse_auxv(str)
      auxv = {}
      sio = StringIO.new(str)
      fetch = -> { Helper.unpack(@bits / 8, sio.read(@bits / 8)) }
      loop do
        type = fetch.call
        val = fetch.call
        case type
        when 7 then auxv[:ld_base] = val # AT_BASE
        when 25 then auxv[:random] = val # AT_RANDOM
        end
        break if type.zero?
      end
      auxv
    end

    def bits_of(elf)
      elf[4] == "\x01" ? 32 : 64
    end

    def match_maps(maps, pattern)
      maps.map { |s| s[3] }.find { |seg| pattern.is_a?(Regexp) ? seg =~ pattern : seg.include?(pattern) }
    end
  end
end
