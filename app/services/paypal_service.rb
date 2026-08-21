# PayPal Checkout (Orders v2 API) — intégration moderne.
# Nécessite ENV: PAYPAL_CLIENT_ID, PAYPAL_SECRET, PAYPAL_MODE ('live' ou 'sandbox')
class PayPalService < ApplicationService
  include Rails.application.routes.url_helpers

  attr_accessor :contribution

  def initialize(contribution)
    @contribution = contribution
  end

  def self.create_order_for(contribution)
    new(contribution).create_order
  end

  def self.capture_order_for(contribution, order_id)
    new(contribution).capture_order(order_id)
  end

  def api_base
    ENV['PAYPAL_MODE'] == 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com'
  end

  def create_order
    uri = URI("#{api_base}/v2/checkout/orders")
    body = {
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: "contrib-#{contribution.id}",
        description: contribution.project.name.to_s.truncate(127),
        amount: {
          currency_code: contribution.project.currency.to_s.upcase,
          value: format('%.2f', contribution.value.to_f)
        }
      }],
      application_context: {
        return_url: paypal_payment_return_project_contribution_url(contribution.project, contribution),
        cancel_url: paypal_payment_cancel_project_contribution_url(contribution.project, contribution),
        user_action: 'PAY_NOW'
      }
    }

    response = post_json(uri, body)
    Rails.logger.info "[PayPal] create_order contrib=#{contribution.id} status=#{response['status']}"
    response
  end

  def capture_order(order_id)
    uri = URI("#{api_base}/v2/checkout/orders/#{order_id}/capture")
    response = post_json(uri, {})
    Rails.logger.info "[PayPal] capture_order contrib=#{contribution.id} order=#{order_id} status=#{response['status']} capture_status=#{capture_status(response)}"
    response
  end

  # URL d'approbation vers laquelle rediriger le contributeur
  def approved_url(order_response)
    link = Array(order_response['links']).find { |l| %w(payer-action approve).include?(l['rel']) }
    link && link['href']
  end

  # Statut de la capture (COMPLETED = argent encaissé, PENDING = eCheck etc.)
  def capture_status(capture_response)
    capture_response.dig('purchase_units', 0, 'payments', 'captures', 0, 'status')
  end

  def capture_id(capture_response)
    capture_response.dig('purchase_units', 0, 'payments', 'captures', 0, 'id')
  end

  private

  def access_token
    uri = URI("#{api_base}/v1/oauth2/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(ENV['PAYPAL_CLIENT_ID'], ENV['PAYPAL_SECRET'])
    request.set_form_data('grant_type' => 'client_credentials')
    response = http_request(uri, request)
    JSON.parse(response.body)['access_token']
  end

  def post_json(uri, payload)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    JSON.parse(http_request(uri, request).body)
  end

  def http_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.request(request)
  end
end
