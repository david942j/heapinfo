module HeapInfo
  # Record libc's base, name, and offsets.
  class Libc < Segment

    # Instantiate a <tt>HeapInfo::Libc</tt> object.
    #
    # @param [Mixed] args See <tt>#HeapInfo::Segment.initialize</tt> for more information.
    def initialize(*args)
      super
      @offset = {}
    end

    # Get the offset of <tt>main_arena</tt> in libc.
    # @return [Integer]
    def main_arena_offset
      return @offset[:main_arena] if @offset[:main_arena]
      return nil unless exhaust_search :main_arena
      @offset[:main_arena]
    end

    # Get the <tt>main_arena</tt> of libc.
    # @return [HeapInfo::Arena]
    def main_arena
      return @main_arena.reload! if @main_arena
      off = main_arena_offset
      return if off.nil?
      @main_arena = Arena.new(off + self.base, process.bits, process.method(:dump))
    end

    # @param [Array] maps See <tt>#HeapInfo::Segment.find</tt> for more information.
    # @param [String] name See <tt>#HeapInfo::Segment.find</tt> for more information.
    # @param [HeapInfo::Process] process The process.
    # @return [HeapInfo::Libc] libc segment found in maps.
    def self.find(maps, name, process)
      obj = super(maps, name)
      obj.send(:process=, process)
      obj
    end

  private
    attr_accessor :process
    # only for searching offset of main_arena now
    def exhaust_search(symbol)
      return false if symbol != :main_arena
      read_main_arena_offset
      true
    end

    def read_main_arena_offset
      key = HeapInfo::Cache::key_libc_offset(self.name)
      @offset = HeapInfo::Cache::read(key) || {}
      return @offset[:main_arena] if @offset.key? :main_arena
      @offset[:main_arena] = resolve_main_arena_offset
      HeapInfo::Cache::write key, @offset
    end

    def resolve_main_arena_offset
      tmp_elf = HeapInfo::TMP_DIR + "/get_arena"
      libc_file = HeapInfo::TMP_DIR + "/libc.so.6"
      ld_file = HeapInfo::TMP_DIR + "/ld.so"
      flags = "-w #{@process.bits == 32 ? '-m32' : ''}"
      %x(cp #{self.name} #{libc_file} && \
         cp #{@process.ld.name} #{ld_file} && \
         gcc #{flags} #{File.expand_path('../tools/get_arena.c', __FILE__)} -o #{tmp_elf} 2>&1 > /dev/null && \
         #{ld_file} --library-path #{HeapInfo::TMP_DIR} #{tmp_elf} && \
         rm #{tmp_elf} #{libc_file} #{ld_file}).to_i(16)
    end
  end
end
