$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'geppetto/version'

task :default => [:build]

task :build do
  system "gem build geppetto.gemspec"
end

desc "Publish gem" 
task :release => :build do
  system "gem push geppetto-#{Geppetto::VERSION}.gem"
end