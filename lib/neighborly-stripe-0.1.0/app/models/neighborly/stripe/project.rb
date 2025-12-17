module Neighborly::Stripe::Project
  extend ActiveSupport::Concern
  
  included do
    has_many :stripe_orders, class_name: 'Neighborly::Stripe::Order', foreign_key: 'project_id'
  end
  
  def setup_stripe_account!
    return if stripe_account_id.present?
    
    account_id = user.create_stripe_connect_account!
    update_column(:stripe_account_id, account_id)
    account_id
  end
  
  def stripe_ready?
    stripe_account_id.present? && user.stripe_onboarding_complete?
  end
  
  def enable_stripe!
    setup_stripe_account! if stripe_account_id.blank?
    
    # Recharger pour avoir les dernières données
    reload
    
    # Activer même si onboarding pas terminé (à compléter plus tard)
    update_column(:use_stripe, true)
    
    stripe_ready?
  end
  
  def process_stripe_payout(amount_cents:)
    return { success: false, error: 'Stripe not enabled for this project' } unless use_stripe?
    return { success: false, error: 'Stripe account not ready' } unless stripe_ready?
    
    begin
      transfer = ::Stripe::Transfer.create({
        amount: amount_cents,
        currency: currency.downcase,
        destination: stripe_account_id,
        metadata: {
          project_id: self.id,
          project_name: self.name
        }
      })
      
      { success: true, transfer: transfer }
    rescue ::Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end
  
  def stripe_balance
    return 0 unless stripe_account_id.present?
    
    begin
      balance = ::Stripe::Balance.retrieve({}, { stripe_account: stripe_account_id })
      balance.available.find { |b| b.currency == currency.downcase }&.amount || 0
    rescue ::Stripe::StripeError
      0
    end
  end
  
  def platform_fee_amount(contribution_amount)
    fee_percentage = ENV.fetch('PLATFORM_FEE', '5.0').to_f / 100
    (contribution_amount * fee_percentage).round
  end
end
