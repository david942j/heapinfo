lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'heapinfo/version'

Gem::Specification.new do |s|
  s.name        = 'heapinfo'
  s.version     = ::HeapInfo::VERSION
  s.date        = '2016-05-21'
  s.summary     = "HeapInfo - interactive heap exploitation helper"
  s.description = "create an interactive heap info interface while exploiting binary (with glibc) with ruby"
  s.authors     = ["david942j"]
  s.email       = ["david942j@gmail.com"]
  s.files       = Dir["lib/**/*.rb"] + Dir["lib/**/tools/*.c"] + %w(README.md)
  s.test_files  = Dir['spec/**/*']
  s.homepage    = 'https://github.com/david942j/heapinfo'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.1.0'
end
