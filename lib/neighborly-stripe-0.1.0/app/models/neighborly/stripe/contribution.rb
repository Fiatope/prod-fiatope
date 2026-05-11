module Neighborly::Stripe::Contribution
  extend ActiveSupport::Concern
  
  included do
    has_one :stripe_order, class_name: 'Neighborly::Stripe::Order', foreign_key: 'contribution_id'
  end
  
  def create_stripe_order(payment_intent_id:, checkout_session_id: nil)
    stripe_currency = normalized_stripe_currency(project.currency)
    amount_minor_units = amount_to_minor_units(value, stripe_currency)

    stripe_order || create_stripe_order!({
      user_id: user.id,
      project_id: project.id,
      stripe_payment_intent_id: payment_intent_id,
      stripe_checkout_session_id: checkout_session_id,
      amount_cents: amount_minor_units,
      currency: stripe_currency,
      platform_fee_cents: project.platform_fee_amount(amount_minor_units),
      status: 'pending'
    })
  end
  
  def stripe_refund
    return { success: false, error: 'No Stripe order found' } unless stripe_order.present?
    return { success: false, error: 'Payment intent not found' } unless stripe_order.stripe_payment_intent_id.present?
    
    begin
      refund = ::Stripe::Refund.create({
        payment_intent: stripe_order.stripe_payment_intent_id,
        metadata: {
          contribution_id: self.id,
          project_id: project.id
        }
      })
      
      stripe_order.update(status: 'refunded')
      { success: true, refund: refund }
    rescue ::Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end
  
  def process_with_stripe?
    project.use_stripe? && project.stripe_ready?
  end

  private

  def normalized_stripe_currency(raw_currency)
    currency_code = raw_currency.to_s.strip.downcase
    return 'eur' if currency_code.blank?

    return normalized_fcfa_currency if %w[fcfa cfa].include?(currency_code)

    currency_code
  end

  def normalized_fcfa_currency
    configured = ENV.fetch('STRIPE_FCFA_CURRENCY', 'xof').to_s.strip.downcase
    %w[xof xaf].include?(configured) ? configured : 'xof'
  end

  def zero_decimal_currency?(currency_code)
    %w[bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf].include?(currency_code.to_s.downcase)
  end

  def amount_to_minor_units(amount, currency_code)
    amount_decimal = amount.to_d
    return amount_decimal.round(0).to_i if zero_decimal_currency?(currency_code)

    (amount_decimal * 100).round(0).to_i
  end
end
