module Neighborly::Mangopay::Contribution
  extend ActiveSupport::Concern
  included do

    has_one :order, class_name: 'Neighborly::Mangopay::Order'

    def mangopay_refund
      begin
        ::Neighborly::Mangopay::Refund.new(self).complete!
      rescue StandardError => e
        return false
      end
    end

    def create_order_in_transition
      self.create_order({
        user_id: user.id,
        project_id: project.id,
        order_key: payment_id
      })
    end

    state_machine :state, initial: :pending do
      after_transition all => :confirmed, :do => :create_order_in_transition
    end
  end
end
