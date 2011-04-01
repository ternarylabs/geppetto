lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'geppetto/version'

Gem::Specification.new do |s|
  s.name       = "geppetto"
  s.version    = Geppetto::VERSION
  s.author     = "Georges Auberger"
  s.email      = "georges@ternarylabs.com"
  s.homepage   = "https://github.com/ternarylabs/geppetto"
  s.platform   = Gem::Platform::RUBY
  s.summary    = "A simple command line tool to help manage Facebook test users and the generation of content."
  s.description = "A simple command line tool to help manage Facebook test users and the generation of content."
  s.has_rdoc   = false
  s.requirements << 'ImageMagick'

  s.files      = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.textile)
  s.executables = %w(geppetto)
  s.default_executable  = 'geppetto'
  s.bindir        = 'bin'
  s.require_paths = ["lib"]
  s.add_dependency('koala', '~>1.0.0.beta2')
  s.add_dependency('thor')
  s.add_dependency('progressbar')
end