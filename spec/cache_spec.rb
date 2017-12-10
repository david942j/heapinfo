# encoding: ascii-8bit

require 'heapinfo'
describe HeapInfo::Cache do
  before(:all) do
    @prefix = 'testcx1dd/'
  end
  after(:each) do
    FileUtils.rm_rf File.join(HeapInfo::Cache::CACHE_DIR, @prefix)
  end
  it 'handle unwritable' do
    org = HeapInfo::Cache::CACHE_DIR
    HeapInfo::Cache.send :remove_const, :CACHE_DIR
    no = '/tmp/no_permission'
    FileUtils.mkdir_p no
    File.chmod 0o444, no # no write permission
    HeapInfo::Cache.const_set :CACHE_DIR, no + '/.cache'
    HeapInfo::Cache.send :init
    expect(HeapInfo::Cache::CACHE_DIR).to eq HeapInfo::TMP_DIR + '/.cache/heapinfo'
    HeapInfo::Cache.send :remove_const, :CACHE_DIR
    HeapInfo::Cache.const_set :CACHE_DIR, org
    FileUtils.rm_rf no
  end

  it 'write' do
    expect(HeapInfo::Cache.write(@prefix + '123', a: 1)).to be true
  end

  it 'read' do
    expect(HeapInfo::Cache.read(@prefix + 'z/zzz')).to be nil
  end

  it 'write and read' do
    key = @prefix + 'fefw/z/zz/xdddd'
    object = { a: { b: 'string', array: [3, '1', 2] }, 'd' => 3 }
    expect(HeapInfo::Cache.read(key)).to be nil
    expect(HeapInfo::Cache.write(key, object)).to be true
    expect(HeapInfo::Cache.read(key)).to eq object
  end

  it 'file corrupted' do
    key = @prefix + 'corrupted'
    HeapInfo::Cache.write(key, 'ok')
    IO.binwrite(File.join(HeapInfo::Cache::CACHE_DIR, key), 'not ok')
    expect(HeapInfo::Cache.read(key)).to be nil
  end
end
