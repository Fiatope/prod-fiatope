lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'neighborly/mangopay/creditcard/version'
# require './lib/recursive_open_struct'

Gem::Specification.new do |spec|
  spec.name          = 'neighborly-mangopay-creditcard'
  spec.version       = Neighborly::Mangopay::Creditcard::VERSION
  spec.authors       = ['Geoffrey Antoine']
  spec.email         = %w(geoffreyantoine1004@gmail.com)
  spec.summary       = 'Neighbor.ly integration with MangoPay.'
  spec.description   = 'Neighbor.ly integration with MangoPay.'
  spec.homepage      = nil
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency             'mangopay'
  spec.add_dependency             'neighborly-mangopay'
  spec.add_dependency             'recursive-open-struct'
  spec.add_dependency             'rails'
  spec.add_dependency             'slim'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'sqlite3'



end
