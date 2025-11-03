module Neighborly::Mangopay
  class OrderProxy
    I18N_SCOPE = 'neighborly.mangopay.order'

    delegate :amount, :amount_escrowed, :description, :meta,
      :reload, :save, :direct_card_payin, to: :order

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def direct_card_payin(payin_params)
      begin
        @payin = ::RecursiveOpenStruct.new(::MangoPay::PayIn::Card::Direct.create(payin_params))
        puts "==================================================="
        puts "===========MANGOPAY PAYIN HAS SUCCEEDED==="
        puts "================ #{@payin} ==========="
        puts "==================================================="
        puts "==================================================="
        return @payin
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "===========MANGOPAY PAYIN WITH CARD HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end

    end

    private

    def order(order_key)
      begin
        @order ||= ::MangoPay::PayIn.fetch(order_key)
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "================MANGOPAY PAYIN FETCH HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
    end
  end
end
