module HeapInfo
  # Record libc's base, name, and offsets.
  class Libc < Segment
    include HeapInfo::Glibc
    # Instantiate a {HeapInfo::Libc} object.
    #
    # @param [Mixed] args See {HeapInfo::Segment#initialize} for more information.
    def initialize(*args)
      super
      @offset = {}
    end

    # Get the offset of +main_arena+ in libc.
    # @return [Integer]
    def main_arena_offset
      return @offset[:main_arena] if @offset[:main_arena]
      return nil unless exhaust_search :main_arena
      @offset[:main_arena]
    end

    # Get the +main_arena+ of libc.
    # @return [HeapInfo::Arena]
    def main_arena
      return @main_arena.reload! if @main_arena
      off = main_arena_offset
      return if off.nil?
      @main_arena = Arena.new(off + base, size_t, dumper)
    end

    # @param [Array] maps See {HeapInfo::Segment#find} for more information.
    # @param [String] name See {HeapInfo::Segment#find} for more information.
    # @param [Integer] bits Either 64 or 32.
    # @param [String] ld_name The loader's realpath, will be used for running subprocesses.
    # @param [Proc] dumper The memory dumper for fetch more information.
    # @return [HeapInfo::Libc] libc segment found in maps.
    def self.find(maps, name, bits, ld_name, dumper)
      obj = super(maps, name)
      obj.size_t = bits / 8
      obj.__send__(:ld_name=, ld_name)
      obj.__send__(:dumper=, dumper)
      obj
    end

    private

    attr_accessor :ld_name
    # only for searching offset of main_arena now
    def exhaust_search(symbol)
      return false if symbol != :main_arena
      read_main_arena_offset
      true
    end

    def read_main_arena_offset
      key = HeapInfo::Cache.key_libc_offset(name)
      @offset = HeapInfo::Cache.read(key) || {}
      return @offset[:main_arena] if @offset.key?(:main_arena)
      @offset[:main_arena] = resolve_main_arena_offset
      HeapInfo::Cache.write(key, @offset)
    end

    def resolve_main_arena_offset
      dir = HeapInfo::Helper.tempfile('')
      FileUtils.mkdir(dir)
      tmp_elf = File.join(dir, 'get_arena')
      libc_file = File.join(dir, 'libc.so.6')
      ld_file = File.join(dir, 'ld.so')
      flags = "-w #{size_t == 4 ? '-m32' : ''}"
      `cp #{name} #{libc_file} && \
         cp #{ld_name} #{ld_file} && \
         gcc #{flags} #{File.expand_path('../tools/get_arena.c', __FILE__)} -o #{tmp_elf} 2>&1 > /dev/null && \
         #{ld_file} --library-path #{dir} #{tmp_elf} && \
         rm -fr #{dir}`.to_i(16)
    end
  end
end
