module Neighborly::Mangopay::Match
  extend ActiveSupport::Concern
  included do

    def mangopay_refund
      ::Neighborly::Mangopay::Refund.new(self).complete!
    end


  end
end
