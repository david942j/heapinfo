module HeapInfo
  attr_reader :base, :arch, :dumper
  def initialize(base, arch, dumper)
    @base, @arch, @dumper = base, arch, dumper
    init
  end

private
  def init
  end
end
