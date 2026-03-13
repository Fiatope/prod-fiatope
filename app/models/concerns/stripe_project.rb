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
    # Unifié avec CampaignSettlement et admin views: ENV['PLATFORM_FEE'] = % affiché (ex: 5.0)
    # tr(',','.') pour gérer le format décimal français dans .env
    fee = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100.0
    fee > 0 ? fee : 0.05
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

  # === WALLET VIRTUEL (équivalent MangoPay Wallet) ===
  # Toutes les méthodes stripe_wallet_* calculent depuis la DB uniquement (pas d'appel API).
  # Pour vérifier avec Stripe API, utiliser verify_stripe_wallet.

  def stripe_contributions
    contributions.where(payment_method: 'Stripe')
  end

  def stripe_wallet_balance
    stripe_contributions.where(state: 'confirmed').sum(:value)
  end

  def stripe_wallet_transferred
    stripe_contributions.where(stripe_transferred: true).sum(:value)
  end

  def stripe_wallet_refunded
    stripe_contributions.where(stripe_refunded: true).sum(:value)
  end

  def stripe_wallet_pending
    stripe_contributions
      .where(state: 'confirmed')
      .where(stripe_refunded: [false, nil])
      .where(stripe_transferred: [false, nil])
      .sum(:value)
  end

  def stripe_wallet_pending_count
    stripe_contributions
      .where(state: 'confirmed')
      .where(stripe_refunded: [false, nil])
      .where(stripe_transferred: [false, nil])
      .count
  end

  def stripe_wallet_status
    total     = stripe_wallet_balance
    pending   = stripe_wallet_pending
    transferred = stripe_wallet_transferred
    refunded  = stripe_wallet_refunded

    return :empty if total.zero?
    return :transferred if pending.zero? && transferred > 0 && refunded.zero?
    return :refunded if pending.zero? && refunded > 0 && transferred.zero?
    return :partial if pending.zero? && transferred > 0 && refunded > 0
    return :collecting if pending > 0 && transferred.zero? && refunded.zero?
    :mixed
  end

  def stripe_wallet_summary
    fee_pct = platform_fee_percentage
    gross   = stripe_wallet_balance
    pending = stripe_wallet_pending
    commission = (gross * fee_pct).round(2)
    stripe_fees_est = stripe_contributions.where(state: 'confirmed').count * 0.25 +
                      gross * 0.029
    net_owner = gross - commission

    {
      gross: gross,
      pending: pending,
      transferred: stripe_wallet_transferred,
      refunded: stripe_wallet_refunded,
      commission: commission,
      stripe_fees_estimate: stripe_fees_est.round(2),
      platform_net_estimate: (commission - stripe_fees_est).round(2),
      net_to_owner: net_owner.round(2),
      fee_pct: (fee_pct * 100).round(1),
      status: stripe_wallet_status,
      contributions_count: stripe_contributions.where(state: 'confirmed').count,
      pending_count: stripe_wallet_pending_count
    }
  end

  def verify_stripe_wallet
    results = { verified: [], mismatches: [], errors: [], totals: {} }
    confirmed = stripe_contributions.where(state: 'confirmed')
    db_total = 0.0
    stripe_total = 0.0

    confirmed.find_each do |c|
      charge_id = c.stripe_charge_id
      if charge_id.blank? && c.payment_id.present?
        begin
          pi = ::Stripe::PaymentIntent.retrieve(c.payment_id)
          charge_id = pi.latest_charge
          c.update_column(:stripe_charge_id, charge_id) if charge_id.present?
        rescue ::Stripe::StripeError => e
          results[:errors] << { contribution_id: c.id, error: "PaymentIntent retrieve: #{e.message}" }
          next
        end
      end

      if charge_id.blank?
        results[:errors] << { contribution_id: c.id, error: "Pas de charge_id" }
        next
      end

      begin
        charge = ::Stripe::Charge.retrieve(charge_id)
        stripe_amount = charge.amount / 100.0
        db_amount = c.value.to_f
        db_total += db_amount
        stripe_total += stripe_amount

        entry = {
          contribution_id: c.id,
          charge_id: charge_id,
          db_amount: db_amount,
          stripe_amount: stripe_amount,
          currency: charge.currency,
          status: charge.status,
          refunded: charge.refunded,
          transferred: c.stripe_transferred || false,
          stripe_fee: nil
        }

        if charge.balance_transaction.present?
          bt = ::Stripe::BalanceTransaction.retrieve(charge.balance_transaction)
          entry[:stripe_fee] = bt.fee / 100.0
        end

        if (db_amount - stripe_amount).abs < 0.02
          results[:verified] << entry
        else
          entry[:difference] = (stripe_amount - db_amount).round(2)
          results[:mismatches] << entry
        end
      rescue ::Stripe::StripeError => e
        results[:errors] << { contribution_id: c.id, charge_id: charge_id, error: e.message }
      end
    end

    results[:totals] = {
      db_total: db_total.round(2),
      stripe_total: stripe_total.round(2),
      match: (db_total - stripe_total).abs < 0.02,
      difference: (stripe_total - db_total).round(2),
      verified_count: results[:verified].size,
      mismatch_count: results[:mismatches].size,
      error_count: results[:errors].size
    }

    results
  end
end
