# frozen_string_literal: true

module StripeProject
  extend ActiveSupport::Concern

  included do
    after_commit :sync_stripe_account_from_user, on: :create
    after_save :sync_stripe_account_from_user, if: :should_sync_stripe?
  end

  def use_stripe?
    use_stripe != false
  end

  def stripe_enabled?
    use_stripe? && stripe_account_ready?
  end

  def stripe_account_ready?
    return false if stripe_account_id.blank?

    begin
      account = Stripe::Account.retrieve(stripe_account_id)
      account.charges_enabled && account.capabilities&.transfers == 'active'
    rescue Stripe::StripeError
      false
    end
  end

  def platform_fee_percentage
    fee = ENV['PLATFORM_FEE_PERCENTAGE']&.to_f
    fee.present? && fee > 0 ? fee : 0.039
  end

  def platform_fee_amount(amount_cents)
    (amount_cents * platform_fee_percentage).round
  end

  def can_accept_stripe_payments?
    use_stripe?
  end

  # === SYNCHRONISATION STRIPE CONNECT ===
  
  def sync_stripe_account_from_user
    return unless user.present?
    return unless user.respond_to?(:stripe_connect_account_id)
    return if stripe_account_id == user.stripe_connect_account_id
    
    if user.stripe_connect_account_id.present?
      update_columns(
        stripe_account_id: user.stripe_connect_account_id,
        use_stripe: true
      )
      Rails.logger.info "StripeProject: Projet #{id} synchronisé avec compte #{user.stripe_connect_account_id}"
    end
  end

  def should_sync_stripe?
    return false unless user.present?
    return false unless user.respond_to?(:stripe_connect_account_id)
    
    user.stripe_connect_account_id.present? && 
      stripe_account_id != user.stripe_connect_account_id
  end

  def stripe_connect_status
    return :no_account unless stripe_account_id.present?
    
    begin
      account = Stripe::Account.retrieve(stripe_account_id)
      if account.charges_enabled && account.payouts_enabled
        :active
      elsif account.charges_enabled
        :charges_only
      else
        :pending
      end
    rescue Stripe::InvalidRequestError
      :invalid
    rescue Stripe::StripeError
      :error
    end
  end
end
