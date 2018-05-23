require 'fileutils'
require 'json'

require 'heapinfo/arena'
require 'heapinfo/cache'
require 'heapinfo/glibc/glibc'
require 'heapinfo/helper'
require 'heapinfo/segment'
require 'heapinfo/tcache'

module HeapInfo
  # Record libc's base, name, and offsets.
  class Libc < Segment
    include HeapInfo::Glibc
    # Instantiate a {HeapInfo::Libc} object.
    #
    # @param [Mixed] args See {HeapInfo::Segment#initialize} for more information.
    def initialize(*args)
      super
    end

    # Get the offset of +main_arena+ in libc.
    # @return [Integer]
    def main_arena_offset
      info['main_arena_offset']
    end

    # Get the +main_arena+ of libc.
    # @return [HeapInfo::Arena]
    def main_arena
      return @main_arena.reload! if @main_arena
      off = main_arena_offset
      return if off.nil?
      @main_arena = Arena.new(off + base, size_t, dumper)
    end

    # Does this glibc support tcache?
    #
    # @return [Boolean]
    #   +true+ or +false+.
    def tcache?
      info['tcache_enable']
    end

    # The tcache object.
    #
    # @return [HeapInfo::Tcache?]
    #   Returns +nil+ if this libc doesn't support tcache.
    def tcache
      return unless tcache?
      @tcache ||= Tcache.new(tcache_base, size_t, dumper)
    end

    # @param [Array] maps See {HeapInfo::Segment#find} for more information.
    # @param [String] name See {HeapInfo::Segment#find} for more information.
    #
    # @option options [Integer] bits Either 64 or 32.
    # @option options [String] ld_name The loader's realpath, will be used for running subprocesses.
    # @option options [Proc] dumper The memory dumper for fetch more information.
    # @option options [Proc] method_heap Method for getting heap segment.
    #
    # @return [HeapInfo::Libc] libc segment found in maps.
    def self.find(maps, name, **options)
      super(maps, name).tap do |obj|
        obj.size_t = options[:bits] / 8
        %i[ld_name dumper method_heap].each do |sym|
          obj.__send__("#{sym}=", options[sym])
        end
      end
    end

    private

    attr_accessor :ld_name, :method_heap
    # Get libc's info.
    def info
      return @info if @info
      # Try to fetch from cache first.
      key = HeapInfo::Cache.key_libc_info(name)
      @info = HeapInfo::Cache.read(key)
      @info ||= execute_libc_info.tap { |i| HeapInfo::Cache.write(key, i) }
    end

    def execute_libc_info
      dir = HeapInfo::Helper.tempfile('')
      FileUtils.mkdir(dir)
      tmp_elf = File.join(dir, 'libc_info')
      libc_file = File.join(dir, 'libc.so.6')
      ld_file = File.join(dir, 'ld.so')
      flags = "-w #{size_t == 4 ? '-m32' : ''}"
      JSON.parse(`cp #{name} #{libc_file} && \
         cp #{ld_name} #{ld_file} && \
         gcc #{flags} #{File.expand_path('tools/libc_info.c', __dir__)} -o #{tmp_elf} 2>&1 > /dev/null && \
         #{ld_file} --library-path #{dir} #{tmp_elf} && \
         rm -fr #{dir}`)
    end

    def tcache_base
      method_heap.call.base + 2 * size_t
    end
  end
end
