require 'rubygems'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.name       = "Geppetto"
    s.version    = "0.9.0"
    s.author     = "Georges Auberger"
    s.email      = "georges@ternarylabs.com"
    s.homepage   = "https://github.com/ternarylabs/geppetto"
    s.platform   = Gem::Platform::RUBY
    s.summary    = "A simple command line tool to help manage Facebook test users and the generation of content."
    s.files      = FileList["{bin}/**/*"].to_a
    s.has_rdoc   = false
    s.requirements << 'ImageMagick'
    s.executables << 'geppetto'
    s.bindir = 'bin'
    s.add_dependency('koala', '~>1.0.0.beta2')
    s.add_dependency('thor')
    s.add_dependency('progressbar')
    s.add_dependency('rmagick')
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end
