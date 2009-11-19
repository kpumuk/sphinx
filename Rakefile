require 'rake'

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

begin
  require 'spec/rake/spectask'

  desc 'Default: run specs'
  task :default => :spec

  desc 'Test the sphinx plugin'
  Spec::Rake::SpecTask.new do |t|
    t.libs << 'lib'
    t.pattern = 'spec/*_spec.rb'
  end
rescue LoadError
  puts 'RSpec not available. Install it with: sudo gem install rspec'
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new(:yard) do |t|
    t.options = ['--title', 'Sphinx Client API Documentation']
    if ENV['PRIVATE']
      t.options.concat ['--protected', '--private']
    else
      t.options << '--no-private' 
    end
  end
rescue LoadError
  puts 'Yard not available. Install it with: sudo gem install yard'
end
