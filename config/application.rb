require File.expand_path('../boot', __FILE__)
require 'logger'
require 'rails/all'
%w(absence acceptance callbacks confirmation exclusion format helper_methods inclusion length numericality presence validates with).each do |validator|
  require "active_model/validations/#{validator}"
end
if Rails.env.development?
  require 'openssl'
end

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  # if Rails.env.development?
  #   OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  # end
  Bundler.require *Rails.groups(assets: %w(development test))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Neighborly
  class Application < Rails::Application
    require 'catarse_monkeymail'

    config.to_prepare do
      Devise::Mailer.layout "email" # email.haml or email.erb
    end

    config.active_job.queue_adapter = :sidekiq

    config.active_record.schema_format = :sql

    # Since Rails 3.1, all folders inside app/ will be loaded automatically
    config.autoload_paths += %W(#{config.root}/lib #{config.root}/lib/**)

    I18n.enforce_available_locales = true

    config.i18n.available_locales = [:fr, :en]
    config.i18n.load_path += Dir[Rails.root.join('app', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.load_path += Dir[Rails.root.join('app', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :fr
    config.i18n.locale = :fr

    # Default encoding for the server
    config.encoding = "utf-8"

    config.filter_parameters += [:password, :password_confirmation]
    config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :local

    # Do not generate specs for views and requests. Also, do not generate assets.
    config.generators do |g|
      g.javascripts false
      g.stylesheets false
      g.helper false
      g.template_engine :slim
      g.test_framework :rspec,
        view_specs: false,
        helper_specs: false,
        fixture: false
    end

    config.active_record.observers = %i(
      authorization_observer
      contact_observer
      contribution_observer
      match_observer
      notification_observer
      payment_observer
      project_observer
      update_observer
      user_observer
      organization_observer
      CatarseMonkeymail::MonkeyProjectObserver
    )

    # Enable the asset pipeline
    config.assets.enabled = true

    # Don't initialize the app when compiling
    config.assets.initialize_on_precompile = false

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.to_prepare do
      Devise::SessionsController.layout 'devise'
      Devise::RegistrationsController.layout proc{ |controller| user_signed_in? ? 'application' : 'devise' }
      Devise::ConfirmationsController.layout 'devise'
      Devise::UnlocksController.layout 'devise'
      Devise::PasswordsController.layout 'devise'
    end
  end
end
