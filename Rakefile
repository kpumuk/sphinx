require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name        = 'sphinx'
    gemspec.summary     = 'Sphinx Client API for Ruby'
    gemspec.description = 'An easy interface to Sphinx standalone full-text search engine. It is implemented as plugin for Ruby on Rails, but can be easily used as standalone library.'
    gemspec.email       = 'kpumuk@kpumuk.info'
    gemspec.homepage    = 'http://github.com/kpumuk/sphinx'
    gemspec.authors     = ['Dmytro Shteflyuk']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts 'Jeweler not available. Install it with: sudo gem install jeweler'
end

desc 'Default: run specs'
task :default => :spec

desc 'Test the sphinx plugin'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs << 'lib'
  t.pattern = 'spec/*_spec.rb'
end

desc 'Generate documentation for the sphinx plugin'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Sphinx Client API'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
