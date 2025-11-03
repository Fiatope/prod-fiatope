module Neighborly::Mangopay::Creditcard
  class Payment
    require "browser"
    attr_reader :engine_name, :customer, :resource, :attrs

    def initialize(engine_name, customer, resource, return_url, attrs = {})
      @engine_name  = engine_name
      @customer     = customer
      @resource     = resource
      @return_url   = return_url
      @attrs        = attrs
    end

    def debit!
      perform_debit!
    end

    def checkout!
      resource.update!(
        payment_id:                       @debit.try(:Id),
        payment_method:                   engine_name,
        payment_service_fee:              0,
        payment_service_fee_paid_by_user: false
      )
      begin
        resource.confirm!
      rescue
        resource.cancel!
      ensure
        resource.cancel! if @debit.try(:Id).blank?
      end
    end

    def successful?
      %w(000000).include? @debit.try(:ResultCode)
    end

    private

    def perform_debit!
      # @resource = contribution
      # @customer = contributeur
      @project = @resource.project
      # browser_infos = Hash.new
      # browser_infos['AcceptHeader'] = "text/html, application/xhtml+xml, application/xml;q=0.9, /;q=0.8"
      # browser_infos['JavaEnabled'] = true
      # browser_infos['Language'] = "FR-FR"
      # browser_infos['ColorDepth'] = 4
      # browser_infos['ScreenHeight'] = 1800
      # browser_infos['ScreenWidth'] = 400
      # browser_infos['TimeZoneOffset'] = "+60"
      # browser_infos['UserAgent'] = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
      # browser_infos['JavascriptEnabled'] = true

      puts "================ ip_address : #{@attrs[:ip_address]} ==========="
      puts "================ browser_info : #{@attrs[:browser_info]} ==========="

      debit_params = {
        AuthorId:       @customer.key,#contributor
        DebitedFunds:   {
          Currency:      @project.currency.upcase,
          Amount:        (@resource.value * 100).to_f
        },
        Fees:           {
          Currency:       @project.currency.upcase,
          Amount:         0.0
        },
        CreditedWalletId:     @project.find_or_create_wallet.wallet_key,# wallet created when project has been created
        CreditedUserId:       @project.user.mangopay_contributor.key,# id of the mangopay user which has created the project and therefore the wallet
        ReturnURL:            @return_url,
        Culture:              'FR',
        CardType:             'CB_VISA_MASTERCARD',
        SecureModeReturnURL:  @return_url,
        SecureMode:           "DEFAULT",
        CardId:               @attrs[:card_key],
        # IpAddress: "127.0.0.1",
        # BrowserInfo: browser_infos
        IpAddress: @attrs[:ip_address],
        BrowserInfo: @attrs[:browser_info]
      }
      begin
        order  = Neighborly::Mangopay::OrderProxy.new(resource.project)
        puts "==================================================="
        puts "================MANGOPAY ORDERPROXY HAS SUCCEEDED==="
        puts "================ #{order} ==========="
        puts "==================================================="
        puts "==================================================="
      rescue  MangoPay::ResponseError => ex
        puts "==================================================="
        puts "================MANGOPAY ORDERPROXY HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end

      begin
        @debit = order.direct_card_payin(debit_params)
        puts "==================================================="
        puts "==========MANGOPAY DIRECT CARD PAYING HAS SUCCEEDED==="
        puts "================ #{@debit} ==========="
        puts "==================================================="
        puts "==================================================="
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "================MANGOPAY  DIRECT CARD PAYING HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
      @debit
    end

    def card
      Mangopay::Card.fetch(@attrs.fetch(:card_key))
    end

    def resource_name
      resource.class.model_name.singular
    end

    def debit_description
      I18n.t('description',
             project_name: resource.try(:project).try(:name),
             scope: "neighborly.mangopay.creditcard.payments.debit.#{resource_name}")
    end

    def project_owner_customer
      @project_owner_customer ||= Neighborly::Mangopay::Customer.new(
        resource.project.user, {}).fetch
    end

    def meta
      PayableResourceSerializer.new(resource).to_json
    end
  end
end
