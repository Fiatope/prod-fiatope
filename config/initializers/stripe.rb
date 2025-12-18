Rails.configuration.stripe = {
  publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  secret_key: ENV['STRIPE_SECRET_KEY']
}

::Stripe.api_key = Rails.configuration.stripe[:secret_key]
::Stripe.api_version = '2023-10-16'

# Enregistrer Stripe dans PaymentEngine après le chargement complet de l'application
Rails.application.config.after_initialize do
  begin
    if defined?(Neighborly::Stripe::Interface) && defined?(PaymentEngine)
      PaymentEngine.new(Neighborly::Stripe::Interface.new).save
      Rails.logger.info "==> Stripe payment engine registered successfully"
    end
  rescue => e
    Rails.logger.error "Error registering Stripe payment engine: #{e.message}"
  end
end
