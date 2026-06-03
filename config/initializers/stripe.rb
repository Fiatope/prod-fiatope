Rails.configuration.stripe = {
  publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  secret_key: ENV['STRIPE_SECRET_KEY']
}

::Stripe.api_key = Rails.configuration.stripe[:secret_key]
::Stripe.max_network_retries = ENV.fetch('STRIPE_MAX_NETWORK_RETRIES', '2').to_i
::Stripe.api_version = '2023-10-16'
