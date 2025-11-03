module Neighborly::Mangopay::Creditcard
  class Interface

    def name
      'mangopay-creditcard'
    end

    def payment_path(resource)
      key = "#{ActiveModel::Naming.param_key(resource)}_id"
      Neighborly::Mangopay::Creditcard::Engine.routes.url_helpers.new_payment_path(key => resource, currency: resource.project.currency)
    end

    def account_path
      false
    end

    def fee_calculator(value)
      TransactionAdditionalFeeCalculator.new(value)
    end

    def payout_class
      Neighborly::Mangopay::Payout
    end

  end
end
