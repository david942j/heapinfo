require 'heapinfo/nil'

describe HeapInfo::Nil do
  before(:all) do
    @nil = HeapInfo::Nil.new
  end
  it 'nil?' do
    expect(@nil.nil?).to be true
  end
  it 'nil chain' do
    expect(@nil.xdd.oao.no_method).to be @nil
  end
  it 'puts' do
    expect(puts(@nil)).to be nil
  end
  it 'respond_to?' do
    expect(@nil.respond_to?(:puts)).to be false
    expect(@nil.respond_to?(:inspect)).to be true
    expect(@nil.respond_to?(:nil?)).to be true
  end
end
