$:.push File.expand_path('../lib', __FILE__)

require 'neighborly/stripe/version'

Gem::Specification.new do |s|
  s.name        = 'neighborly-stripe'
  s.version     = Neighborly::Stripe::VERSION
  s.authors     = ['Fiatope Team']
  s.email       = ['tech@fiatope.com']
  s.homepage    = 'https://github.com/fiatope/neighborly-stripe'
  s.summary     = 'Stripe Connect integration for Neighborly crowdfunding platform'
  s.description = 'Rails Engine for Stripe Connect payment processing in Fiatope/Kwendoo'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  s.add_dependency 'rails', '~> 6.1'
  s.add_dependency 'stripe', '~> 10.0'
  
  s.add_development_dependency 'rspec-rails'
end
