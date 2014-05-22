libdir = File.expand_path('../lib/', __FILE__)
$:.unshift libdir unless $:.include?(libdir)

require 'red_storm/version'

Gem::Specification.new do |s|
  s.name        = 'lookout-redstorm'
  s.version     = RedStorm::VERSION
  s.authors     = ['Ian Smith']
  s.email       = ['ian.smith@lookout.com']
  s.homepage    = ''
  s.summary     = 'Lookout fork of RedStorm'
  s.description = 'JRuby integration & DSL for the Storm distributed realtime computation system'
  s.license     = "Apache 2.0"

  s.files         = Dir.glob("{lib/**/*}") + Dir.glob("{ivy/*.xml}") + Dir.glob("{examples/**/*}") + Dir.glob("{src/**/*.java}") + Dir.glob("{bin/**/*}") + %w(lookout-redstorm.gemspec Rakefile README.md CHANGELOG.md LICENSE.md)
  s.require_paths = ['lib']
  s.bindir        = 'bin'
  s.executables   = ['redstorm']

  s.add_development_dependency 'rspec', '~> 2.13'
  s.add_runtime_dependency 'rake'
end
