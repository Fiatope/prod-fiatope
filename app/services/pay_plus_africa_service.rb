class PayPlusAfricaService < ApplicationService

  attr_accessor :contribution

  def initialize(contribution)
    @contribution = contribution
    @currency = "xof"
  end

  def self.initialize_payment_for(*args, &block)
    new(*args, &block).initialize_payment_for
  end

  def self.confirm_payment_for(contribution, transaction)
    new(contribution).confirm_payment_for(transaction)
  end

  def pay_plus_africa_webpay_url
    ENV['PAY_PLUS_AFRICA_ENDPOINT']
  end

  def pay_plus_africa_confirm_url(invoiceToken)
    "#{ENV['PAY_PLUS_AFRICA_CONFIRM']}#{invoiceToken}"
  end

  def pay_plus_africa_api_key
    ENV['PAY_PLUS_AFRICA_API_KEY']
  end

  def pay_plus_africa_token
    ENV['PAY_PLUS_AFRICA_TOKEN']
  end

  def initialize_payment_for
    uri = URI.parse(pay_plus_africa_webpay_url)

    header = {
        "Authorization" => "Bearer #{pay_plus_africa_token}",
        "Apikey" => pay_plus_africa_api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json"
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, header)

    if ENV['HOST'] == "ns357509.ip-91-121-149.eu"
      host = ENV['HOST']
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: host)
      notif_url = Rails.application.routes.url_helpers.webhooks_pay_plus_africa_payment_confirmations_url(host: host)
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: host)

    elsif Rails.env.development?
      ngrok_host = "http://b367de05.ngrok.io"
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: ngrok_host)
      notif_url = Rails.application.routes.url_helpers.webhooks_pay_plus_africa_payment_confirmations_url(host: ngrok_host)
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, host: ngrok_host)

    else
      cancel_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, protocol: :https)
      notif_url = Rails.application.routes.url_helpers.webhooks_pay_plus_africa_payment_confirmations_url(protocol: :https)
      return_url = Rails.application.routes.url_helpers.edit_project_contribution_url(contribution.project, contribution, protocol: :https)

    end

    body_json = {
      commande: {
        invoice: {
          total_amount: contribution.cfa_value || contribution.value * contribution.conversion_rate,
          devise: @currency
        },
        actions: {
          cancel_url: cancel_url,
          return_url: return_url,
          callback_url: notif_url
        },
        custom_data: {
          return_data: "#{contribution.project.id}-#{contribution.id}"
        }
      }
    }.to_json

    Rails.logger.debug('***' + uri.inspect)
    Rails.logger.debug('***' + body_json.inspect)
    request.body = body_json

    response = http.request(request)
    response_json = JSON.parse(response.body)
    Rails.logger.debug('###' + response_json.inspect)

    contribution.pay_plus_africa_transactions.create!(
      order_id_string: "#{contribution.unique_identifier_for('pay_plus_africa')}",
      reference: "ref Merchant",
      notif_token: response_json["token"],
      status_string: response_json["response_code"],
      payment_url: response_json["response_text"]
    )
  end

  def confirm_payment_for(transaction)
    uri = URI.parse(pay_plus_africa_confirm_url(transaction.notif_token))

    header = {
        "Authorization" => "Bearer #{pay_plus_africa_token}",
        "Apikey" => pay_plus_africa_api_key
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri, header)

    Rails.logger.debug('***' + uri.inspect)
    response = http.request(request)
    response_json = JSON.parse(response.body)

    Rails.logger.debug('###' + response_json.inspect)

    response_json
  end

end
