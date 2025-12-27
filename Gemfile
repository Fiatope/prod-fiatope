
source 'http://rubygems.org'

ruby '3.1.4'

gem 'rails', '6.1.3'

gem 'rails-observers', '~> 0.1.2'
gem 'active_model_serializers'
gem 'json-jwt'

gem 'redis'
gem 'sidekiq'
gem 'sidekiq-cron'
gem 'sprockets', '~> 3.7.2'
# State machine for attributes on models
gem 'state_machines'
gem 'state_machines-activerecord'

# Database and data related
gem 'pg'
gem 'postgres-copy'
gem 'pg_search'

gem 'net-http-digest_auth'

gem 'recursive-open-struct'
gem 'faraday'
# Payment engines
# Stripe Connect
gem 'stripe', '~> 10.0'
gem 'neighborly-stripe', :path => "lib/neighborly-stripe-0.1.0"

# Neighborly mangopay
gem 'cocoon'
gem 'country_select'
gem 'neighborly-mangopay-creditcard', :path => "lib/neighborly-mangopay-creditcard-0.1.18"
gem 'neighborly-mangopay', :path => "lib/neighborly-mangopay-0.1.11"


# Neigbhor.ly Engines
gem 'neighborly-admin', :git => 'https://github.com/jengweneg/neighborly-admin-1.2.0-kf.git', :branch => 'update_giftify'


# Turns every field on a editable one - Admin dependencies
gem "best_in_place", git: "https://github.com/mmotherwell/best_in_place"

# Decorators
gem 'draper'

# PDF
gem 'wicked_pdf'
# gem 'wkhtmltopdf-binary' # Commenté: utilise wkhtmltopdf système (apt) pour économiser espace disque Docker


# Frontend stuff
#gem 'slim-rails'
gem 'slim'
gem 'jquery-rails'
gem 'browser'

# Authentication and Authorization
gem 'omniauth'
gem 'omniauth-oauth2', '~> 1.3.1'
gem 'omniauth-twitter'
gem 'omniauth-google-oauth2', '0.2.1'
gem 'omniauth-linkedin'
gem 'omniauth-facebook', '4.0.0'
gem 'omniauth_openid_connect', '0.1' # '~> 0.3.5'
gem 'openid_connect'
gem 'devise'#, github: 'heartcombo/devise', branch: 'ca-omniauth-2'
gem 'ezcrypto'
gem 'pundit'

# Email marketing
gem 'catarse_monkeymail'

# HTML manipulation and formatting
gem 'simple_form'
gem 'auto_html', '~>1.6.4'
gem 'kaminari'
#gem 'temple', '0.7.6'

# Uploads
gem 'carrierwave'
gem 'rmagick', :require => 'rmagick'
gem 'dropzonejs-rails'

# Other Tools
gem 'has_permalink'
gem 'ranked-model'
gem 'inherited_resources'
gem 'has_scope'
gem 'responders'
gem 'video_info'
gem 'geocoder'
gem 'font-awesome-sass', '~> 4.4.0'
gem 'world-flags', github: 'kristianmandrup/world-flags', branch: 'master'
gem 'timezone'

gem 'rollbar'

# Feature branch still to be merged by original gem author
gem 'as_csv', require: 'as_csv', github: 'Irio/as_csv', branch: 'localization-of-headers'
gem 'gctools'

# Excel
gem 'spreadsheet'

# Communication with API
gem 'httpclient'

gem 'puma'

# For rake task send_summary_CSV
gem 'net-sftp'

group :production do
  gem 'google-analytics-rails'

  # Gem used to handle image uploading
  gem 'unf'
  gem 'fog-aws'

  # Workers, forks and all that jazz
  gem 'unicorn'
  gem "unicorn-rails"

  # Enabling Gzip on Heroku
  # If you don't use Heroku, please comment the line below.
  #gem 'heroku-deflater', '>= 0.4.1'

  # Make heroku serve static assets and login with stdout
  gem 'rails_12factor', group: [:production]

end

group :development do
  gem 'byebug', platform: [:mri, :mingw, :x64_mingw]
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'ffaker'
  gem 'letter_opener'
  #gem 'quiet_assets'
  gem 'spring', '~>1.3.3'
  gem 'thin'
end

group :development, :test do
  gem 'awesome_print'
  gem 'dotenv-rails'
  gem 'minitest'
  gem 'rspec-rails'
end

group :test do
  gem 'weekdays'
  gem 'fakeweb', require: false
  gem 'launchy'
  gem 'database_cleaner'
  gem 'shoulda-matchers'
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'coveralls', require: false
end

#gem 'asset_sync'
gem 'coffee-rails'
gem 'uglifier'
gem 'font-icons-rails', github: 'josemarluedke/font-icons-rails', branch: 'fix-svgz'
gem 'zurb-foundation', '~> 4.3.2'
gem 'turbolinks'
gem 'nprogress-rails'
gem 'pjax_rails'
gem 'initjs', github: 'jengweneg/initjs', branch: 'fix-safari'
gem 'remotipart'

# Sass
gem 'bootstrap-sass', '~> 3.3.6'
gem 'sass-rails', '>= 3.2'
# decorator
gem 'jquery-ui-sass-rails'
gem 'pony'

gem 'wicked' # multiple step wizard
gem  'recaptcha', '~> 4.4.0', require: "recaptcha/rails"
gem 'http_accept_language'

# Zip files
gem 'rubyzip'
gem 'get_process_mem'

# JavaScript Runtime
gem 'execjs'
gem 'mini_racer', platforms: :ruby
gem 'psych', '< 4'

