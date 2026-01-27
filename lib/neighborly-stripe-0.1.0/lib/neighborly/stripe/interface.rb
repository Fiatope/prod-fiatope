module Neighborly
  module Stripe
    class Interface
      def name
        'stripe'
      end

      def payment_path(contribution)
        "/stripe/projects/#{contribution.project.id}/payments/new?contribution_id=#{contribution.id}"
      end

      def fee_calculator(value)
        calculator = Neighborly::Stripe::FeeCalculator.new(value)
        OpenStruct.new(
          net_amount: calculator.net_amount,
          gateway_fee: calculator.gateway_fee,
          platform_fee: calculator.platform_fee,
          gross_amount: calculator.gross_amount
        )
      end

      def review_path(contribution)
        "/projects/#{contribution.project.permalink}/contributions/#{contribution.id}"
      end

      def can_list_cards?
        false
      end
    end
  end
end
