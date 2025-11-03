Neighborly::Application.configure do
  $stdout.sync = true
  Slim::Engine.set_options pretty: false
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes
  config.cache_classes = !!Sidekiq.server?
  config.eager_load = !!Sidekiq.server?

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.public_file_server.enabled = true

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  config.assets.css_compressor = :sass

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Set to :debug to see everything in the log.
  # config.log_level = :debug
  # config.logger = Logger.new(STDOUT)

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  config.assets.precompile << ['normalize.css', 'animate.css', 'cookies.css', 'default.css','backgroundsize.htc']
  
  # reload_gems = %w(neighborly-mangopay-creditcard neighborly-mangopay)
  # config.autoload_paths += Gem.loaded_specs.values.inject([]){ |a,gem| a += gem.load_paths if reload_gems.include? gem.name; a }
  # require 'active_support/dependencies'
  # ActiveSupport::Dependencies.explicitly_unloadable_constants += reload_gems.map { |gem| gem.classify }

  # mailcatcher configs

  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
end

