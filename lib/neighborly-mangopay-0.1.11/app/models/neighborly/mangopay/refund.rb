module Neighborly::Mangopay
  class Refund
    FIXED_OPERATIONAL_FEE_IN_CENTS = 18

    attr_reader :paid_resource

    def initialize(paid_resource)
      @paid_resource = paid_resource
    end

    def complete!(amount = paid_resource.value)
      unless amount.zero?
        refunded_resource = ::RecursiveOpenStruct.new(::MangoPay::PayIn.refund(paid_resource.payment_id, {
                                AuthorId: paid_resource.user.mangopay_contributor_key,
                                DebitedFunds: {
                                  Currency: paid_resource.project.currency.upcase,
                                  Amount: amount.to_f * 100
                                },
                                Fees: {
                                  Currency: paid_resource.project.currency.upcase,
                                  Amount: FIXED_OPERATIONAL_FEE_IN_CENTS
                                }
                              })
                            )
        fail refunded_resource['ResultMessage'] if refunded_resource['ResultCode'] != '000000'
        Order.find_by(order_key:paid_resource.payment_id).update_attributes(refund_key: refunded_resource.Id)
      end
    end

    def refundable_fees(refund_amount)
      percentual_fee = if paid_resource.payment_service_fee_paid_by_user
        refund_amount / paid_resource.value * paid_resource.payment_service_fee
      else
        0
      end

      (percentual_fee - FIXED_OPERATIONAL_FEE_IN_CENTS).round(2)
    end

    private

    def resource_amount
      to_be_refunded = if paid_resource.payment_service_fee_paid_by_user
        paid_resource.value + paid_resource.payment_service_fee
      else
        paid_resource.value
      end
      (to_be_refunded * 100 - FIXED_OPERATIONAL_FEE_IN_CENTS).round
    end
  end
end
