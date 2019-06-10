# encoding: ascii-8bit
# frozen_string_literal: true

require 'heapinfo/helper'

describe HeapInfo::Helper do
  describe 'unpack' do
    it '32bit' do
      expect(HeapInfo::Helper.unpack(4, "\x15\xCD\x5b\x07")).to eq 123_456_789
    end
    it '64bit' do
      expect(HeapInfo::Helper.unpack(8, "\xEF\xCD\xAB\xEF\xBE\xAD\xDE\x00")).to eq 0xdeadbeefabcdef
    end
  end

  it 'proc' do
    expect { HeapInfo::Helper.exe_of 0 }.to raise_error ArgumentError
  end

  describe 'parse_maps' do
    before(:all) do
      @files_dir = File.expand_path('files', __dir__)
    end
    it '32bit' do
      maps = IO.binread(@files_dir + '/32bit_maps')
      expect(HeapInfo::Helper.parse_maps(maps)).to eq [
        [0x8048000, 0x8049000, 'r-xp', '/home/heapinfo/examples/uaf/uaf'],
        [0x8049000, 0x804a000, 'r--p', '/home/heapinfo/examples/uaf/uaf'],
        [0x804a000, 0x804b000, 'rw-p', '/home/heapinfo/examples/uaf/uaf'],
        [0xf73d4000, 0xf73d7000, 'rw-p', ''],
        [0xf73d7000, 0xf73f3000, 'r-xp', '/usr/lib32/libgcc_s.so.1'],
        [0xf73f3000, 0xf73f4000, 'rw-p', '/usr/lib32/libgcc_s.so.1'],
        [0xf73f4000, 0xf7438000, 'r-xp', '/lib32/libm-2.19.so'],
        [0xf7438000, 0xf7439000, 'r--p', '/lib32/libm-2.19.so'],
        [0xf7439000, 0xf743a000, 'rw-p', '/lib32/libm-2.19.so'],
        [0xf743a000, 0xf75df000, 'r-xp', '/lib32/libc-2.19.so'],
        [0xf75df000, 0xf75e1000, 'r--p', '/lib32/libc-2.19.so'],
        [0xf75e1000, 0xf75e2000, 'rw-p', '/lib32/libc-2.19.so'],
        [0xf75e2000, 0xf75e5000, 'rw-p', ''],
        [0xf75e5000, 0xf76c1000, 'r-xp', '/usr/lib32/libstdc++.so.6.0.19'],
        [0xf76c1000, 0xf76c5000, 'r--p', '/usr/lib32/libstdc++.so.6.0.19'],
        [0xf76c5000, 0xf76c6000, 'rw-p', '/usr/lib32/libstdc++.so.6.0.19'],
        [0xf76c6000, 0xf76ce000, 'rw-p', ''],
        [0xf76db000, 0xf76dd000, 'rw-p', ''],
        [0xf76dd000, 0xf76de000, 'r-xp', '[vdso]'],
        [0xf76de000, 0xf76fe000, 'r-xp', '/lib32/ld-2.19.so'],
        [0xf76fe000, 0xf76ff000, 'r--p', '/lib32/ld-2.19.so'],
        [0xf76ff000, 0xf7700000, 'rw-p', '/lib32/ld-2.19.so'],
        [0xffdd7000, 0xffdf8000, 'rw-p', '[stack]']
      ]
    end
    it '64bit' do
      maps = IO.binread(@files_dir + '/64bit_maps')
      expect(HeapInfo::Helper.parse_maps(maps)).to eq [
        [0x400000, 0x401000, 'r-xp', '/home/heapinfo/examples/uaf/uaf'],
        [0x600000, 0x601000, 'r--p', '/home/heapinfo/examples/uaf/uaf'],
        [0x601000, 0x602000, 'rw-p', '/home/heapinfo/examples/uaf/uaf'],
        [0x7f65ac7b8000, 0x7f65ac7ce000, 'r-xp', '/lib/x86_64-linux-gnu/libgcc_s.so.1'],
        [0x7f65ac7ce000, 0x7f65ac9cd000, '---p', '/lib/x86_64-linux-gnu/libgcc_s.so.1'],
        [0x7f65ac9cd000, 0x7f65ac9ce000, 'rw-p', '/lib/x86_64-linux-gnu/libgcc_s.so.1'],
        [0x7f65ac9ce000, 0x7f65acad3000, 'r-xp', '/lib/x86_64-linux-gnu/libm-2.19.so'],
        [0x7f65acad3000, 0x7f65accd2000, '---p', '/lib/x86_64-linux-gnu/libm-2.19.so'],
        [0x7f65accd2000, 0x7f65accd3000, 'r--p', '/lib/x86_64-linux-gnu/libm-2.19.so'],
        [0x7f65accd3000, 0x7f65accd4000, 'rw-p', '/lib/x86_64-linux-gnu/libm-2.19.so'],
        [0x7f65accd4000, 0x7f65ace8f000, 'r-xp', '/lib/x86_64-linux-gnu/libc-2.19.so'],
        [0x7f65ace8f000, 0x7f65ad08e000, '---p', '/lib/x86_64-linux-gnu/libc-2.19.so'],
        [0x7f65ad08e000, 0x7f65ad092000, 'r--p', '/lib/x86_64-linux-gnu/libc-2.19.so'],
        [0x7f65ad092000, 0x7f65ad094000, 'rw-p', '/lib/x86_64-linux-gnu/libc-2.19.so'],
        [0x7f65ad094000, 0x7f65ad099000, 'rw-p', ''],
        [0x7f65ad099000, 0x7f65ad17f000, 'r-xp', '/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.19'],
        [0x7f65ad17f000, 0x7f65ad37e000, '---p', '/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.19'],
        [0x7f65ad37e000, 0x7f65ad386000, 'r--p', '/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.19'],
        [0x7f65ad386000, 0x7f65ad388000, 'rw-p', '/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.19'],
        [0x7f65ad388000, 0x7f65ad39d000, 'rw-p', ''],
        [0x7f65ad39d000, 0x7f65ad3c0000, 'r-xp', '/lib/x86_64-linux-gnu/ld-2.19.so'],
        [0x7f65ad5aa000, 0x7f65ad5af000, 'rw-p', ''],
        [0x7f65ad5bc000, 0x7f65ad5bf000, 'rw-p', ''],
        [0x7f65ad5bf000, 0x7f65ad5c0000, 'r--p', '/lib/x86_64-linux-gnu/ld-2.19.so'],
        [0x7f65ad5c0000, 0x7f65ad5c1000, 'rw-p', '/lib/x86_64-linux-gnu/ld-2.19.so'],
        [0x7f65ad5c1000, 0x7f65ad5c2000, 'rw-p', ''],
        [0x7fff3d1e8000, 0x7fff3d209000, 'rw-p', '[stack]'],
        [0x7fff3d309000, 0x7fff3d30b000, 'r-xp', '[vdso]'],
        [0xffffffffff600000, 0xffffffffff601000, 'r-xp', '[vsyscall]']
      ]
    end

    it 'color' do
      HeapInfo::Helper.toggle_color(on: true)
      expect(HeapInfo::Helper.color('0x1234')).to eq "\e[38;5;153m0x1234\e[0m"
      expect(HeapInfo::Helper.color('OAO')).to eq "\e[38;5;209mOAO\e[0m"
    end
  end
end
