require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :test => :spec
task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new(:yard) do |t|
    t.options = ['--title', 'Sphinx Client API Documentation']
  if ENV['PRIVATE']
    t.options.concat ['--protected', '--private']
  else
    t.options.concat ['--protected', '--no-private']
  end
end

require 'bundler'
Bundler::GemHelper.install_tasks

namespace :fixtures do
  FIXTURES_DIR = File.expand_path('../spec/fixtures', __FILE__)

  desc 'Update textures for sphinx requests'
  task :requests do
    rm Dir.glob("#{FIXTURES_DIR}/requests/*.dat")
    Dir["#{FIXTURES_DIR}/requests/php/*.php"].each do |file|
      puts name = File.basename(file, '.php')
      File.open(File.join(File.dirname(file), '..', "#{name}.dat"), 'w') do |f|
        f.write `env SPHINX_MOCK_REQUEST=1 php "#{file}"`
      end
    end
  end

  desc 'Update textures for sphinx responses'
  task :responses do
    rm Dir.glob("#{FIXTURES_DIR}/responses/*.dat")
    Dir["#{FIXTURES_DIR}/responses/php/*.php"].each do |file|
      puts name = File.basename(file, '.php')
      File.open(File.join(File.dirname(file), '..', "#{name}.dat"), 'w') do |f|
        f.write `env SPHINX_MOCK_RESPONSE=1 php "#{file}"`
      end
    end
  end
end

desc 'Update binary fixtures'
task :fixtures => %w[ fixtures:requests fixtures:responses]
