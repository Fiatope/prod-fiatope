require 'float_extensions'

module Neighborly::Mangopay::Creditcard
  class TransactionInclusiveFeeCalculator < TransactionFeeCalculatorBase
    using FloatExtensions

    # Base calculation of fees
    # 1.8% + 18¢
    def net_amount
      ((transaction_value.to_f * 0.018) + 0.18).floor_with_two_decimal_places
    end
  end
end
