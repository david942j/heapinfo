require 'fileutils'
require 'json'

require 'heapinfo/arena'
require 'heapinfo/cache'
require 'heapinfo/glibc/glibc'
require 'heapinfo/helper'
require 'heapinfo/segment'

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

    def tcache?
      info['tcache_enable']
    end

    # @param [Array] maps See {HeapInfo::Segment#find} for more information.
    # @param [String] name See {HeapInfo::Segment#find} for more information.
    # @param [Integer] bits Either 64 or 32.
    # @param [String] ld_name The loader's realpath, will be used for running subprocesses.
    # @param [Proc] dumper The memory dumper for fetch more information.
    # @return [HeapInfo::Libc] libc segment found in maps.
    def self.find(maps, name, bits, ld_name, dumper)
      super(maps, name).tap do |obj|
        obj.size_t = bits / 8
        obj.__send__(:ld_name=, ld_name)
        obj.__send__(:dumper=, dumper)
      end
    end

    private

    attr_accessor :ld_name
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
  end
end
