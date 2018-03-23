lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'heapinfo/version'
require 'date'

Gem::Specification.new do |s|
  s.name        = 'heapinfo'
  s.version     = ::HeapInfo::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'HeapInfo - interactive heap exploitation helper'
  s.description = <<-EOS
Create an interactive memory info interface while pwn / exploiting.
Useful for rubiers writing exploit scripts.
HeapInfo can be used even when target is being ptraced,
this tool helps a lot when one needs to debug an ptraced process.
EOS
  s.authors     = ['david942j']
  s.email       = ['david942j@gmail.com']
  s.files       = Dir['lib/**/*.rb'] + Dir['lib/**/tools/*.c'] + %w[README.md]
  s.homepage    = 'https://github.com/david942j/heapinfo'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.1.0'

  s.add_runtime_dependency 'dentaku', '~> 3'

  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3.7'
  s.add_development_dependency 'rubocop', '~> 0.52'
  s.add_development_dependency 'simplecov', '~> 0.16.0'
end
