module Neighborly
  module Stripe
    class Order < ApplicationRecord
      self.table_name = 'stripe_orders'
      
      belongs_to :user
      belongs_to :project
      belongs_to :contribution, optional: true
      
      serialize :metadata, JSON
      
      validates :amount_cents, presence: true, numericality: { greater_than: 0 }
      validates :currency, presence: true
      validates :status, presence: true
      
      scope :pending, -> { where(status: 'pending') }
      scope :completed, -> { where(status: 'completed') }
      scope :failed, -> { where(status: 'failed') }
      scope :refunded, -> { where(status: 'refunded') }
      
      def amount
        Money.new(amount_cents, currency.upcase)
      end
      
      def platform_fee
        return Money.new(0, currency.upcase) unless platform_fee_cents
        Money.new(platform_fee_cents, currency.upcase)
      end
      
      def net_amount
        Money.new(amount_cents - (platform_fee_cents || 0), currency.upcase)
      end
      
      def mark_as_completed!(charge_id: nil, transfer_id: nil)
        update_attributes = { status: 'completed' }
        update_attributes[:stripe_charge_id] = charge_id if charge_id
        update_attributes[:stripe_transfer_id] = transfer_id if transfer_id
        
        update(update_attributes)
      end
      
      def mark_as_failed!
        update(status: 'failed')
      end
      
      def retrieve_payment_intent
        return nil unless stripe_payment_intent_id.present?
        
        begin
          ::Stripe::PaymentIntent.retrieve(stripe_payment_intent_id)
        rescue ::Stripe::InvalidRequestError
          nil
        end
      end
      
      def retrieve_checkout_session
        return nil unless stripe_checkout_session_id.present?
        
        begin
          ::Stripe::Checkout::Session.retrieve(stripe_checkout_session_id)
        rescue ::Stripe::InvalidRequestError
          nil
        end
      end
    end
  end
end
