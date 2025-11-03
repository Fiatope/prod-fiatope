class OrangeMoneyService < ApplicationService

  attr_accessor :contribution

  def initialize(contribution)
    @contribution = contribution
    @currency = (Rails.env.development? ? "OUV" : "XOF")
  end

  def self.initialize_payment_for(*args, &block)
    new(*args, &block).initialize_payment_for
  end

  def env_for(env_name)
    case @contribution.project.address_state
    when /cameroon/i
      @currency = 'XAF'
      ENV["#{env_name}_CAMEROON"] 
    when /mali/i
      @currency = 'XOF'
      ENV["#{env_name}_MALI"]
    when /niger/i
      @currency = 'XOF'
      ENV["#{env_name}_NIGER"]
    else
      ENV["#{env_name}_DEFAULT"]
    end
  end

  def orange_money_webpay_url
    env_for('ORANGE_MONEY_WEBPAY_URL')
  end

  def orange_money_merchant_key
    env_for('ORANGE_MONEY_MERCHANT_KEY')
  end

  def initialize_payment_for
    uri = URI.parse(orange_money_webpay_url)

    provider = case @contribution.project.address_state
    when /cameroon/i
      @currency = 'XAF'
      "orange_money_cameroon"
    when /mali/i
      @currency = 'XOF'
      "orange_money_mali"
    when /niger/i
      @currency = 'XOF'
      "orange_money_niger"
    else
      "orange_money_default"
    end


    access_token = VendorOauthToken.get_access_token_for(provider)
    header = { "Authorization" => "Bearer #{access_token}", "Accept" => "application/json", "Content-Type" => "application/json" }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, header)

    if ENV['HOST'] == "ns357509.ip-91-121-149.eu"
      host = [ENV['HOST'], (ENV['PORT'].present? ? ENV['PORT'] : 3000)].join(":")
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: host)
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: host)
      notif_url = Rails.application.routes.url_helpers.webhooks_orange_money_payment_confirmations_url(host: host)

    elsif Rails.env.development?
      ngrok_host = "http://b367de05.ngrok.io"
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: ngrok_host)
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: ngrok_host)
      # cancel_url = Rails.application.routes.url_helpers.cancel_project_contribution_url(contribution.project, contribution, host: ngrok_host)
      notif_url = Rails.application.routes.url_helpers.webhooks_orange_money_payment_confirmations_url(host: ngrok_host)

    else
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, protocol: :https)
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, protocol: :https)
      # cancel_url = Rails.application.routes.url_helpers.cancel_project_contribution_url(contribution.project, contribution)
      notif_url = Rails.application.routes.url_helpers.webhooks_orange_money_payment_confirmations_url(protocol: :https)

    end

    body_json = {
      merchant_key: orange_money_merchant_key,
      currency: @currency,
      order_id: "#{contribution.unique_identifier_for('orange_money')}",
      amount: contribution.cfa_value,
      return_url: return_url,
      cancel_url: cancel_url,
      notif_url: notif_url,
      lang: (I18n.locale.to_s || "en"),
      reference: "ref KWENDOO #{rand(1..100000)}"
    }.to_json
    Rails.logger.debug('***' + uri.inspect)
    Rails.logger.debug('***' + body_json.inspect)
    request.body = body_json

    response = http.request(request)
    response_json = JSON.parse(response.body)
    Rails.logger.debug('###' + response_json.inspect)

    contribution.orange_money_transactions.create!(
      order_id_string: "#{contribution.unique_identifier_for('orange_money')}",
      reference: "ref Merchant",
      lang: (I18n.locale.to_s || "en"),
      pay_token: response_json["pay_token"],
      status_string: response_json["message"],
      payment_url: response_json["payment_url"],
      notif_token: response_json["notif_token"]
    )
  end

end
