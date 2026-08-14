class MollieService < ApplicationService
  include Rails.application.routes.url_helpers

  attr_accessor :contribution

  def initialize(contribution)
    @contribution = contribution
  end

  # Créer un paiement Mollie
  def create_payment
    return error_response('Mollie not configured') unless mollie_configured?

    begin
      payment = Mollie::Payment.create(
        amount: {
          value: format_amount(@contribution.value),
          currency: currency_code
        },
        description: payment_description,
        redirect_url: success_url,
        webhook_url: webhook_url,
        metadata: {
          contribution_id: @contribution.id,
          project_id: @contribution.project.id,
          user_id: @contribution.user.id
        }
      )

      Rails.logger.info "[MollieService] Payment created: id=#{payment.id} amount=#{payment.amount.value} #{payment.amount.currency} status=#{payment.status}"

      {
        success: true,
        payment_id: payment.id,
        checkout_url: payment.checkout_url,
        status: payment.status
      }
    rescue Mollie::Exception => e
      Rails.logger.error "[MollieService] Payment creation failed: #{e.class} #{e.message}"
      error_response(e.message)
    end
  end

  # Récupérer un paiement Mollie
  def self.get_payment(payment_id)
    return nil unless mollie_configured?

    begin
      Mollie::Payment.get(payment_id)
    rescue Mollie::Exception => e
      Rails.logger.error "[MollieService] Get payment failed: #{e.message}"
      nil
    end
  end

  # Vérifier le statut d'un paiement
  def self.check_payment_status(payment_id)
    payment = get_payment(payment_id)
    return nil unless payment

    {
      id: payment.id,
      status: payment.status,
      paid: payment.paid?,
      amount: payment.amount.value,
      currency: payment.amount.currency,
      metadata: payment.metadata
    }
  end

  # Créer un remboursement
  def self.create_refund(payment_id, amount = nil)
    return error_response('Mollie not configured') unless mollie_configured?

    begin
      refund_params = { paymentId: payment_id }
      refund_params[:amount] = amount if amount.present?

      refund = Mollie::Payment::Refund.create(refund_params)

      Rails.logger.info "[MollieService] Refund created: id=#{refund.id} payment_id=#{payment_id} amount=#{refund.amount.value}"

      {
        success: true,
        refund_id: refund.id,
        status: refund.status
      }
    rescue Mollie::Exception => e
      Rails.logger.error "[MollieService] Refund failed: #{e.message}"
      error_response(e.message)
    end
  end

  private

  def format_amount(value)
    # Mollie attend le format "10.00" (2 décimales obligatoires)
    sprintf('%.2f', value.to_f)
  end

  def currency_code
    # Mollie supporte EUR, USD, GBP, etc.
    # Pour les projets en FCFA, on utilise EUR
    project_currency = @contribution.project.currency.to_s.upcase
    
    case project_currency
    when 'FCFA', 'XOF', 'XAF'
      'EUR' # Mollie ne supporte pas FCFA, on convertit en EUR
    else
      project_currency
    end
  end

  def payment_description
    "Contribution projet: #{@contribution.project.name.truncate(50)}"
  end

  def success_url
    project_contribution_url(
      @contribution.project,
      @contribution,
      host: ENV['HOST'] || 'localhost:3000',
      protocol: Rails.env.production? ? 'https' : 'http'
    )
  end

  def webhook_url
    mollie_webhook_url(
      host: ENV['HOST'] || 'localhost:3000',
      protocol: Rails.env.production? ? 'https' : 'http'
    )
  end

  def self.mollie_configured?
    ENV['MOLLIE_API_KEY'].present?
  end

  def mollie_configured?
    self.class.mollie_configured?
  end

  def self.error_response(message)
    {
      success: false,
      error: message
    }
  end

  def error_response(message)
    self.class.error_response(message)
  end
end
