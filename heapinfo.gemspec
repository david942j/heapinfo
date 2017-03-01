lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'heapinfo/version'
require 'date'

Gem::Specification.new do |s|
  s.name        = 'heapinfo'
  s.version     = ::HeapInfo::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'HeapInfo - interactive heap exploitation helper'
  s.description = 'create an interactive memory info interface while pwn / exploiting'
  s.authors     = ['david942j']
  s.email       = ['david942j@gmail.com']
  s.files       = Dir['lib/**/*.rb'] + Dir['lib/**/tools/*.c'] + %w(README.md)
  s.homepage    = 'https://github.com/david942j/heapinfo'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.1.0'

  s.add_runtime_dependency 'dentaku', '~> 2'

  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rubocop', '~> 0.46'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'simplecov', '~> 0.13.0'
  s.add_development_dependency 'codeclimate-test-reporter', '~> 0.6'
end
