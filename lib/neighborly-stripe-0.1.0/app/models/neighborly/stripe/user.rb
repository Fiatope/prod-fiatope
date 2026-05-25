module Neighborly::Stripe::User
  extend ActiveSupport::Concern

  included do
    has_many :stripe_orders, class_name: 'Neighborly::Stripe::Order', foreign_key: 'user_id'

    # Synchroniser le compte Stripe sur tous les projets quand il change.
    after_save :sync_stripe_account_to_all_projects, if: :saved_change_to_stripe_connect_account_id?
  end

  def sync_stripe_account_to_all_projects
    return unless stripe_connect_account_id.present?

    synced = 0
    skipped = 0
    projects.find_each do |project|
      if stripe_project_account_locked?(project)
        skipped += 1
        next
      end

      project.update_columns(
        stripe_account_id: stripe_connect_account_id,
        use_stripe: true
      )
      synced += 1
    end

    Rails.logger.info "Stripe: Compte #{stripe_connect_account_id} synchronise sur #{synced} projet(s) pour #{email}; #{skipped} conserve(s) car deja en reglement"
  end

  def stripe_customer
    return @stripe_customer if @stripe_customer

    if stripe_customer_id.present?
      begin
        @stripe_customer = ::Stripe::Customer.retrieve(stripe_customer_id)
      rescue ::Stripe::InvalidRequestError
        @stripe_customer = create_stripe_customer
      end
    else
      @stripe_customer = create_stripe_customer
    end

    @stripe_customer
  end

  def create_stripe_connect_account!(force: false)
    return stripe_connect_account_id if stripe_connect_account_id.present? && !force

    previous_account_id = stripe_connect_account_id
    params = stripe_connect_account_create_params
    if previous_account_id.present?
      params[:metadata] = params.fetch(:metadata, {}).merge(
        replaced_account_id: previous_account_id,
        replaced_at: Time.current.iso8601
      )
    end

    account = ::Stripe::Account.create(params)

    attrs = {
      stripe_connect_account_id: account.id,
      stripe_onboarding_complete: false
    }
    attrs[:stripe_account_type] = account.type if respond_to?(:stripe_account_type=)
    attrs[:stripe_charges_enabled] = account.charges_enabled if respond_to?(:stripe_charges_enabled=)
    attrs[:stripe_payouts_enabled] = account.payouts_enabled if respond_to?(:stripe_payouts_enabled=)

    # Sauvegarder l'ID Stripe meme si une validation utilisateur non liee bloque update/save.
    update_columns(attrs)
    sync_stripe_account_to_all_projects

    Rails.logger.warn "Stripe: Compte connecte #{previous_account_id} remplace par #{account.id} pour #{email}" if previous_account_id.present?

    account.id
  end

  def stripe_account_onboarding_url(refresh_url:, return_url:)
    create_stripe_connect_account! if stripe_connect_account_id.blank?
    nil
  end

  def stripe_onboarding_complete?
    return false unless stripe_connect_account_id.present?

    begin
      account = ::Stripe::Account.retrieve(stripe_connect_account_id)
      ready = stripe_account_ready_for_transfers?(account)
      update_stripe_account_cache(account, ready)
      ready
    rescue ::Stripe::InvalidRequestError
      update_column(:stripe_onboarding_complete, false) if persisted?
      false
    rescue ::Stripe::StripeError => e
      Rails.logger.warn "stripe_onboarding_complete? API error for #{stripe_connect_account_id}: #{e.message}"
      false
    end
  end

  def stripe_onboarding_complete!(force_check: false)
    update_column(:stripe_onboarding_complete, false) if force_check && persisted?
    stripe_onboarding_complete?
  end

  def stripe_dashboard_url
    nil
  end

  private

  def stripe_project_account_locked?(project)
    settlement_type = project.respond_to?(:stripe_settlement_type) ? project.stripe_settlement_type.to_s : ''
    payout_status = project.respond_to?(:stripe_payout_status) ? project.stripe_payout_status.to_s : ''
    payout_id = project.respond_to?(:stripe_payout_id) ? project.stripe_payout_id : nil

    settlement_type == 'transferred' ||
      payout_id.present? ||
      %w[pending in_transit paid failed canceled].include?(payout_status)
  end

  def stripe_connect_account_create_params
    {
      type: 'custom',
      country: stripe_connect_country,
      email: email,
      capabilities: {
        transfers: { requested: true }
      },
      business_type: profile_type == 'organization' ? 'company' : 'individual',
      business_profile: {
        name: stripe_connect_business_name,
        product_description: 'Collecte de fonds via la plateforme Fiatope',
        url: ENV['FIATOPE_PUBLIC_URL'].presence || ENV['APP_HOST'].presence || 'https://www.fiatope.com',
        support_email: ENV['EMAIL_CONTACT'].presence || 'contact@fiatope.com',
        support_phone: mobile_phone.to_s.presence
      }.compact,
      metadata: {
        user_id: id.to_s,
        platform: 'fiatope',
        profile_type: profile_type.to_s
      }
    }
  end

  def stripe_connect_country
    residence_country.to_s.upcase.presence || 'FR'
  end

  def stripe_connect_business_name
    if profile_type == 'organization' && organization&.name.present?
      organization.name.to_s.truncate(100)
    else
      name.to_s.truncate(100)
    end
  end

  def stripe_account_ready_for_transfers?(account)
    account.payouts_enabled &&
      stripe_nested_value(account.capabilities, :transfers) == 'active' &&
      stripe_account_requirements_due(account).empty?
  end

  def stripe_account_requirements_due(account)
    requirements = account.requirements
    (Array(stripe_nested_value(requirements, :currently_due)) + Array(stripe_nested_value(requirements, :past_due))).uniq
  end

  def stripe_nested_value(object, key)
    return nil if object.blank?
    return object.public_send(key) if object.respond_to?(key)
    return object[key.to_s] if object.respond_to?(:[])

    nil
  rescue
    nil
  end

  def update_stripe_account_cache(account, ready)
    attrs = { stripe_onboarding_complete: ready }
    attrs[:stripe_account_type] = account.type if respond_to?(:stripe_account_type=)
    attrs[:stripe_charges_enabled] = account.charges_enabled if respond_to?(:stripe_charges_enabled=)
    attrs[:stripe_payouts_enabled] = account.payouts_enabled if respond_to?(:stripe_payouts_enabled=)
    update_columns(attrs) if persisted?
  end

  def create_stripe_customer
    customer = ::Stripe::Customer.create(
      email: email,
      name: name,
      metadata: {
        user_id: id,
        platform: 'fiatope'
      }
    )

    update_column(:stripe_customer_id, customer.id)
    customer
  end
end
