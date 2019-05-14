lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require 'heapinfo/version'

Gem::Specification.new do |s|
  s.name        = 'heapinfo'
  s.version     = ::HeapInfo::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'HeapInfo - interactive heap exploitation helper'
  s.description = <<-EOS
Provides an interactive memory info interface when pwning / exploiting.
This is for Rubiers to write exploit and debug in one script.
HeapInfo can be used even when the target is being ptraced,
pretty helpful when one needs to debug a ptraced process.
  EOS
  s.authors     = ['david942j']
  s.email       = ['david942j@gmail.com']
  s.files       = Dir['lib/**/*.rb'] + Dir['lib/**/tools/*.c'] + %w[README.md]
  s.homepage    = 'https://github.com/david942j/heapinfo'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.3'

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/david942j/heapinfo/issues',
    'documentation_uri' => 'https://www.rubydoc.info/github/david942j/heapinfo/master',
    'homepage_uri' => 'https://github.com/david942j/heapinfo',
    'source_code_uri' => 'https://github.com/david942j/heapinfo'
  }

  s.add_runtime_dependency 'dentaku', '~> 3'

  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3.7'
  s.add_development_dependency 'rubocop', '~> 0.59'
  s.add_development_dependency 'simplecov', '~> 0.16.0'
  s.add_development_dependency 'yard', '~> 0.9'
end
