module Neighborly::Stripe::Contribution
  extend ActiveSupport::Concern
  
  included do
    has_one :stripe_order, class_name: 'Neighborly::Stripe::Order', foreign_key: 'contribution_id'
  end
  
  def create_stripe_order(payment_intent_id:, checkout_session_id: nil)
    stripe_order || create_stripe_order!({
      user_id: user.id,
      project_id: project.id,
      stripe_payment_intent_id: payment_intent_id,
      stripe_checkout_session_id: checkout_session_id,
      amount_cents: (value * 100).to_i,
      currency: project.currency.downcase,
      platform_fee_cents: project.platform_fee_amount((value * 100).to_i),
      status: 'pending'
    })
  end
  
  def stripe_refund
    return { success: true, already_refunded: true } if respond_to?(:stripe_refunded?) && stripe_refunded?
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
end
