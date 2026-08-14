# Mollie Payment Gateway Configuration
# Documentation: https://docs.mollie.com
# Gem: https://github.com/mollie/mollie-api-ruby

if ENV['MOLLIE_API_KEY'].present?
  Mollie::Client.configure do |config|
    config.api_key = ENV['MOLLIE_API_KEY']
    config.open_timeout = 60
    config.read_timeout = 60
  end

  Rails.logger.info "[Mollie] Initialized with API key: #{ENV['MOLLIE_API_KEY'][0..7]}..."
else
  Rails.logger.warn "[Mollie] No API key configured (MOLLIE_API_KEY missing)"
end
