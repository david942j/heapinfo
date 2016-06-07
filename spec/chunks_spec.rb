# encoding: ascii-8bit
require 'heapinfo'
describe HeapInfo::Chunks do
  before(:each) do
    @chunks = HeapInfo::Chunks.new
    @chunks << 0; @chunks << 1; @chunks << 2
  end
  it '<<' do
    expect(@chunks.size).to be 3
    @chunks << ("\x00"*16).to_chunk
    expect(@chunks.size).to be 4
  end
  it 'each' do
    @chunks.each_with_index{|c, idx|
      expect(c).to be idx
    }
  end
  it 'to_s' do
    expect(@chunks.to_s).to eq @chunks.instance_variable_get(:@chunks).map(&:to_s).join("\n")
  end
  it 'size' do
    expect(@chunks.size).to eq @chunks.instance_variable_get(:@chunks).size
    expect(@chunks.length).to eq @chunks.instance_variable_get(:@chunks).length
  end
end
