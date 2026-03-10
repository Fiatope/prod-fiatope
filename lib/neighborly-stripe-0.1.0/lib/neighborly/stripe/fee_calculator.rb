module Neighborly
  module Stripe
    class FeeCalculator
      attr_reader :value

      STRIPE_PERCENTAGE = 0.014  # 1.4%
      STRIPE_FIXED = 0.25        # 0.25€
      PLATFORM_PERCENTAGE = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100

      def initialize(value)
        @value = value.to_f
      end

      def gateway_fee
        (@value * STRIPE_PERCENTAGE + STRIPE_FIXED).round(2)
      end

      def platform_fee
        (@value * PLATFORM_PERCENTAGE).round(2)
      end

      def net_amount
        (@value - gateway_fee).round(2)
      end

      def gross_amount
        @value
      end

      def total_fees
        (gateway_fee + platform_fee).round(2)
      end
    end
  end
end
