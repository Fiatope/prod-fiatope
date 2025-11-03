module Neighborly::Mangopay
  class Error         < StandardError; end
  class NoBankAccount < Error;         end

  class Payout
    def initialize(project)
      @project   = project
      @project_owner = @project.user
    end

    def complete!
      return "Already funded" if @project.state == "successful"
      raise 'The customer doesn\'t have a bank account to credit.' if !@project_owner.refund_ready?

      begin
        res = ::RecursiveOpenStruct.new(::MangoPay::PayOut::BankWire.create(
            AuthorId: @project_owner.mangopay_contributor_key,
            DebitedWalletId: @project.mangopay_wallet_handler.wallet_key,
            DebitedFunds: {
              Currency: @project.currency.upcase,
              Amount: (amount_in_cents).to_f
            },
            Fees: {
              Currency: @project.currency.upcase,
              Amount: (total_platform_fee_in_cents).to_f
            },
            BankAccountId: @project_owner.bank_information.key
          )
        )
        ::Payout.create(
          project_id: @project.id,
          mangopay_id: res["Id"],
          payment_service: "Mangopay",
          status: res["Status"],
          result_code: res["ResultCode"],
          result_message: res["ResultMessage"],
          value: res["DebitedFunds"]["Amount"].to_d/100
        )
        if res.Status != "FAILED"
          # @project.finish
          @project.push_to_paid
        else
          raise "Error while transfering fund, contact the administrator"
        end
      rescue Exception => e
        raise e.message
      end
    end

    def amount
      # @project.pledged
      ::ProjectTotalBuilder.new(@project, 'mangopay-creditcard').attributes[:pledged]
    end

    def total_platform_fee
      # (@project.pledged * ::Configuration.fetch('platform_fee_percentage').to_f)
      (::ProjectTotalBuilder.new(@project, 'mangopay-creditcard').attributes[:pledged] * ::Configuration.fetch('platform_fee_percentage').to_f)
    end

    def total_platform_fee_in_cents
      (total_platform_fee * 100).round
    end

    protected

    def amount_in_cents
      (amount * 100).round
    end
  end
end
