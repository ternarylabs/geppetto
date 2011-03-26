task :build do
  system "gem build bundler.gemspec"
end
 
task :release => :build do
  system "gem push bundler-#{Bunder::VERSION}"
end