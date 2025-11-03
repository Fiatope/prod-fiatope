lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'neighborly/mangopay/version'

Gem::Specification.new do |spec|
  spec.name          = 'neighborly-mangopay'
  spec.version       = Neighborly::Mangopay::VERSION
  spec.authors       = ['Irio Musskopf', 'Geoffrey Antoine']
  spec.email         = %w(iirineu@gmail.com geoffreyantoine1004@gmail.com)
  spec.summary       = 'Neighbor.ly integration with MangoPay.'
  spec.description   = 'Neighbor.ly integration with MangoPay.'
  spec.homepage      = nil
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency             'mangopay'
  spec.add_dependency             'draper'
  spec.add_dependency             'recursive-open-struct'
  spec.add_dependency             'rails'
  spec.add_dependency             'carrierwave'
  spec.add_dependency             'sidekiq'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'sqlite3'
end
