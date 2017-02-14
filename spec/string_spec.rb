# encoding: ascii-8bit
require 'heapinfo'
describe String do
  it 'to_chunk' do
    chunk = "\x00\x00\x00\x00\x00\x00\x00\x00g\x00\x00\x00\x00\x00\x00\x00".to_chunk
    expect(chunk.class).to be HeapInfo::Chunk
    expect(chunk.size).to be 0x60
    expect(chunk.flags).to eq [:non_main_arena, :mmapped, :prev_inuse]
  end

  it 'to_chunks' do
    chunks = [0, 0x21, 0, 0, 0, 0x41].pack('Q*').to_chunks
    expect(chunks.size).to be 2
    chunks.each do |chunk| # test each
      expect(chunk.size & 15).to be 0
    end
  end
end
