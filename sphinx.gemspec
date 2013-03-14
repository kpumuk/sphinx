# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'sphinx/version'

Gem::Specification.new do |s|
  s.name        = 'sphinx'
  s.version     = Sphinx::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Dmytro Shteflyuk']
  s.email       = ['kpumuk@kpumuk.info']
  s.homepage    = 'http://github.com/kpumuk/sphinx'
  s.summary     = %q{Sphinx Client API for Ruby}
  s.description = %q{An easy interface to Sphinx standalone full-text search engine. It is implemented as plugin for Ruby on Rails, but can be easily used as standalone library.}

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'yard'

  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {spec}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files = ['README.md', 'CHANGELOG.md']
  s.rdoc_options     = ['--charset=UTF-8']
  s.require_paths    = ['lib']
end
