module Neighborly::Stripe::User
  extend ActiveSupport::Concern

  STRIPE_PHONE_COUNTRY_CALLING_CODES = {
    'FR' => '33', 'CM' => '237', 'CI' => '225', 'SN' => '221',
    'BJ' => '229', 'TG' => '228', 'BF' => '226', 'ML' => '223',
    'NE' => '227', 'GN' => '224', 'GA' => '241', 'CG' => '242',
    'CD' => '243', 'TD' => '235', 'CF' => '236', 'RW' => '250',
    'BI' => '257', 'MA' => '212', 'DZ' => '213', 'TN' => '216',
    'MG' => '261', 'MU' => '230', 'SC' => '248', 'KM' => '269',
    'DJ' => '253', 'ET' => '251', 'KE' => '254', 'UG' => '256',
    'TZ' => '255', 'GH' => '233', 'NG' => '234', 'ZA' => '27',
    'BE' => '32', 'CH' => '41', 'LU' => '352', 'DE' => '49',
    'ES' => '34', 'IT' => '39', 'GB' => '44', 'NL' => '31',
    'PT' => '351', 'US' => '1', 'CA' => '1'
  }.freeze

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

  def create_stripe_connect_account!(force: false, tos_accepted: false)
    return stripe_connect_account_id if stripe_connect_account_id.present? && !force

    previous_account_id = stripe_connect_account_id
    params = stripe_connect_account_create_params(tos_accepted: tos_accepted)
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

  def stripe_connect_phone_number
    raw_phone = mobile_phone.to_s.strip
    return nil if raw_phone.blank?

    normalized = raw_phone.gsub(/[^\d+]/, '')
    normalized = "+#{normalized[2..]}" if normalized.start_with?('00')
    return normalized if stripe_connect_e164_phone?(normalized)
    return nil if normalized.start_with?('+')

    digits = normalized.gsub(/\D/, '')
    return nil if digits.blank?

    stripe_connect_phone_country_candidates.each do |country|
      calling_code = STRIPE_PHONE_COUNTRY_CALLING_CODES[country]
      next if calling_code.blank?

      local_digits = digits.sub(/\A0+/, '')
      with_existing_code = "+#{digits}"
      return with_existing_code if digits.start_with?(calling_code) && stripe_connect_e164_phone?(with_existing_code)

      with_country_code = "+#{calling_code}#{local_digits}"
      return with_country_code if stripe_connect_e164_phone?(with_country_code)
    end

    nil
  end

  def stripe_connect_account_token_for_payout_sync(country: nil, tos_accepted: false, individual_verification: nil, company_verification: nil)
    stripe_connect_account_token_id(
      (country.presence || stripe_connect_country),
      tos_accepted: tos_accepted,
      individual_verification: individual_verification,
      company_verification: company_verification
    )
  end

  def stripe_connect_person_token_for_payout_sync(country: nil, verification: nil)
    api_key = stripe_connect_account_token_api_key
    return nil if api_key.blank?

    token = ::Stripe::Token.create(
      { person: stripe_connect_person_token_payload(country.presence || stripe_connect_country, verification: verification) },
      { api_key: api_key }
    )
    token.id
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

  def stripe_connect_account_create_params(tos_accepted: false)
    params = {
      type: 'custom',
      country: stripe_connect_country,
      email: email,
      capabilities: {
        transfers: { requested: true }
      },
      business_type: stripe_connect_business_type,
      business_profile: {
        name: stripe_connect_business_name,
        product_description: 'Collecte de fonds via la plateforme Fiatope',
        url: ENV['FIATOPE_PUBLIC_URL'].presence || ENV['APP_HOST'].presence || 'https://www.fiatope.com',
        support_email: ENV['EMAIL_CONTACT'].presence || 'contact@fiatope.com',
        support_phone: stripe_connect_phone_number
      }.compact,
      metadata: {
        user_id: id.to_s,
        platform: 'fiatope',
        profile_type: profile_type.to_s
      }
    }

    if tos_accepted
      account_token_id = stripe_connect_account_token_id(params[:country], tos_accepted: tos_accepted)
      if account_token_id.present?
        params[:account_token] = account_token_id
        params.delete(:business_type)
      end
    end

    params
  end

  def stripe_connect_account_token_id(country, tos_accepted:, individual_verification: nil, company_verification: nil)
    api_key = stripe_connect_account_token_api_key
    return nil if api_key.blank?

    token = ::Stripe::Token.create(
      {
        account: stripe_connect_account_token_payload(
          country,
          tos_accepted: tos_accepted,
          individual_verification: individual_verification,
          company_verification: company_verification
        )
      },
      { api_key: api_key }
    )
    token.id
  end

  def stripe_connect_account_token_api_key
    ENV['STRIPE_PUBLISHABLE_KEY'].presence || ENV['STRIPE_SECRET_KEY'].presence
  end

  def stripe_connect_account_token_payload(country, tos_accepted:, individual_verification: nil, company_verification: nil)
    payload = {
      business_type: stripe_connect_business_type
    }
    payload[:tos_shown_and_accepted] = true if tos_accepted

    if stripe_connect_business_type == 'company'
      company_payload = stripe_connect_company_payload(country)
      company_payload[:verification] = company_verification if company_verification.present?
      payload[:company] = company_payload
    else
      individual_payload = stripe_connect_individual_payload(country)
      individual_payload[:verification] = individual_verification if individual_verification.present?
      payload[:individual] = individual_payload
    end

    payload.compact
  end

  def stripe_connect_business_type
    profile_type == 'organization' ? 'company' : 'individual'
  end

  def stripe_connect_company_payload(country)
    payload = {
      name: stripe_connect_business_name,
      phone: stripe_connect_phone_number,
      address: stripe_connect_address_payload(country)
    }

    if organization.respond_to?(:registration_number) && organization.registration_number.present?
      registration_number = organization.registration_number.to_s.strip.upcase
      payload[:registration_number] = registration_number
      payload[:tax_id] = registration_number if registration_number.match?(/\A\d{9}(\d{5})?\z/)
    end

    payload.compact
  end

  def stripe_connect_individual_payload(country)
    name_parts = stripe_connect_name_parts

    {
      first_name: name_parts[:first_name],
      last_name: name_parts[:last_name],
      email: email,
      phone: stripe_connect_phone_number,
      nationality: nationality.to_s.upcase.presence,
      address: stripe_connect_address_payload(country),
      dob: stripe_connect_dob_payload
    }.compact
  end

  def stripe_connect_person_token_payload(country, verification: nil)
    payload = stripe_connect_individual_payload(country)
    payload[:verification] = verification if verification.present?
    payload
  end

  def stripe_connect_address_payload(country)
    info = bank_information
    return nil if info.blank?

    {
      line1: info.owner_address.to_s.presence,
      city: info.owner_city.to_s.presence,
      state: info.owner_region.to_s.presence,
      postal_code: info.owner_postal_code.to_s.presence,
      country: country.to_s.upcase.presence || stripe_connect_country
    }.compact
  end

  def stripe_connect_dob_payload
    return nil if birthday.blank?

    {
      day: birthday.day,
      month: birthday.month,
      year: birthday.year
    }
  end

  def stripe_connect_name_parts
    parts = name.to_s.strip.split(/\s+/)
    first_name = parts.first.presence || email.to_s.split('@').first.presence || 'Utilisateur'
    last_name = (parts[1..] || []).join(' ').presence || first_name

    {
      first_name: first_name,
      last_name: last_name
    }
  end

  def stripe_connect_phone_country_candidates
    [
      residence_country,
      nationality,
      bank_information&.other_country,
      stripe_iban_country(bank_information&.iban),
      ENV['STRIPE_CONNECT_DEFAULT_COUNTRY'],
      'FR'
    ].map { |country| country.to_s.upcase.strip }
     .select { |country| country.match?(/\A[A-Z]{2}\z/) }
     .uniq
  end

  def stripe_connect_e164_phone?(phone)
    phone.to_s.match?(/\A\+[1-9]\d{6,14}\z/)
  end

  def stripe_connect_country
    stripe_connect_country_candidates.each do |country|
      return country if stripe_country_spec_available?(country)
    end

    'FR'
  end

  def stripe_connect_country_candidates
    [
      stripe_iban_country(bank_information&.iban),
      bank_information&.other_country,
      residence_country,
      ENV['STRIPE_CONNECT_DEFAULT_COUNTRY'],
      'FR'
    ].map { |country| country.to_s.upcase.strip }
     .select { |country| country.match?(/\A[A-Z]{2}\z/) }
     .uniq
  end

  def stripe_iban_country(iban)
    iban.to_s.upcase.gsub(/\s+/, '')[/\A[A-Z]{2}/]
  end

  def stripe_country_spec_available?(country)
    Rails.cache.fetch("stripe_country_spec_available:#{country}", expires_in: 12.hours) do
      ::Stripe::CountrySpec.retrieve(country)
      true
    rescue ::Stripe::StripeError => e
      Rails.logger.warn "Stripe: pays Connect #{country} ignore pour #{email}: #{e.message}"
      false
    end
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
    future_requirements = stripe_nested_value(account, :future_requirements)
    (
      Array(stripe_nested_value(requirements, :currently_due)) +
      Array(stripe_nested_value(requirements, :past_due)) +
      Array(stripe_nested_value(future_requirements, :currently_due)) +
      Array(stripe_nested_value(future_requirements, :past_due))
    ).uniq
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
