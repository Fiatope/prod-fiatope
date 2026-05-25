require 'open-uri'
require 'tempfile'

module Neighborly
  module Stripe
    class PayoutProfileSyncService < ApplicationService
      Result = Struct.new(:success, :errors, :warnings, keyword_init: true) do
        def success?
          success
        end
      end

      PLATFORM_NAME = 'fiatope'.freeze
      PLATFORM_URL = 'https://www.fiatope.com'.freeze

      def initialize(user, request_ip: nil, user_agent: nil, tos_accepted: false)
        @user = user
        @request_ip = request_ip
        @user_agent = user_agent
        @tos_accepted = tos_accepted
        @errors = []
        @warnings = []
      end

      def call
        unless stripe_configured?
          errors << 'Configuration Stripe absente: STRIPE_SECRET_KEY doit etre defini avant toute demande de retrait.'
          return result
        end

        unless user.payout_profile_complete?
          errors << 'Profil de retrait incomplet.'
          return result
        end

        ensure_connect_account!
        ensure_platform_managed_account!
        sync_account_identity!
        sync_bank_account!
        sync_kyc_documents!
        refresh_onboarding_flags!
        verify_stripe_payout_ready!

        result
      rescue ::Stripe::StripeError => e
        errors << "Stripe API: #{e.message}"
        result
      rescue => e
        errors << e.message
        result
      end

      private

      attr_reader :user, :request_ip, :user_agent, :errors, :warnings

      def result
        Result.new(success: errors.empty?, errors: errors, warnings: warnings)
      end

      def stripe_configured?
        ENV['STRIPE_SECRET_KEY'].present?
      end

      def ensure_connect_account!
        return if errors.any?
        return if user.stripe_connect_account_id.present?

        user.create_stripe_connect_account!
      rescue ::Stripe::StripeError => e
        errors << "Creation du compte Stripe impossible: #{e.message}"
      end

      def ensure_platform_managed_account!
        return if errors.any?

        account = stripe_account
        return if platform_managed_account?(account)

        errors << "Compte Stripe #{account.id} incompatible avec le profil de retrait local: il doit etre de type Custom ou avoir requirement_collection=application. Deliez ce compte puis recreez le profil de retrait."
      rescue ::Stripe::StripeError => e
        errors << "Verification du compte Stripe impossible: #{e.message}"
      end

      def platform_managed_account?(account)
        account.type == 'custom' || stripe_nested_value(account.controller, :requirement_collection) == 'application'
      end

      def sync_account_identity!
        return if errors.any?

        name_parts = split_name(user.name)
        account_params = {
          business_type: business_type,
          email: user.email,
          business_profile: business_profile_payload,
          settings: {
            payouts: {
              schedule: {
                interval: 'manual'
              }
            }
          },
          metadata: {
            platform: PLATFORM_NAME,
            user_id: user.id.to_s,
            profile_type: user.profile_type.to_s,
            payout_profile_complete: user.payout_profile_complete?.to_s
          }
        }

        if business_type == 'company'
          account_params[:company] = company_payload
        else
          account_params[:individual] = individual_payload(name_parts)
        end

        tos_payload = tos_acceptance_payload
        account_params[:tos_acceptance] = tos_payload if tos_payload.present?

        ::Stripe::Account.update(user.stripe_connect_account_id, account_params)
        sync_representative_person!(name_parts) if business_type == 'company'
      rescue ::Stripe::StripeError => e
        errors << "Synchronisation identite Stripe impossible: #{e.message}"
      end

      def sync_representative_person!(name_parts)
        payload = individual_payload(name_parts).merge(
          email: user.email,
          phone: user.mobile_phone.to_s.presence,
          relationship: {
            representative: true,
            executive: true,
            title: 'Representant legal'
          }
        ).compact

        if representative_person.present?
          @representative_person = ::Stripe::Account.update_person(
            user.stripe_connect_account_id,
            representative_person.id,
            payload
          )
        else
          @representative_person = ::Stripe::Account.create_person(user.stripe_connect_account_id, payload)
        end
      end

      def representative_person
        return @representative_person if defined?(@representative_person)

        people = ::Stripe::Account.list_persons(user.stripe_connect_account_id, limit: 100)
        @representative_person = people.data.find { |person| stripe_nested_value(person.relationship, :representative) == true }
      end

      def sync_bank_account!
        return if errors.any?

        info = user.bank_information
        return if info.blank?

        iban = info.iban.to_s.strip.upcase.gsub(/\s+/, '')
        if iban.blank?
          errors << 'IBAN obligatoire pour synchroniser le compte bancaire vers Stripe.'
          return
        end

        token = ::Stripe::Token.create(
          bank_account: {
            country: bank_country(info),
            currency: 'eur',
            account_holder_name: bank_account_holder_name,
            account_holder_type: business_type,
            account_number: iban
          }
        )

        ::Stripe::Account.update(user.stripe_connect_account_id, external_account: token.id)
      rescue ::Stripe::StripeError => e
        errors << "Synchronisation bancaire Stripe impossible: #{e.message}"
      end

      def sync_kyc_documents!
        return if errors.any?

        if business_type == 'company'
          sync_company_documents!
          sync_representative_documents!
        else
          sync_individual_documents!
        end
      end

      def sync_individual_documents!
        attach_individual_verification_document('IDENTITY_PROOF', :document)
        attach_individual_verification_document('ADDRESS_PROOF', :additional_document)
      end

      def sync_representative_documents!
        attach_person_verification_document('IDENTITY_PROOF', :document)
        attach_person_verification_document('ADDRESS_PROOF', :additional_document)
      end

      def sync_company_documents!
        registration_file_ids = upload_documents_for('REGISTRATION_PROOF', 'account_requirement')
        if registration_file_ids.any?
          ::Stripe::Account.update(
            user.stripe_connect_account_id,
            documents: {
              company_registration_verification: {
                files: registration_file_ids
              }
            }
          )

          verification_ids = upload_documents_for('REGISTRATION_PROOF', 'additional_verification', limit: 2)
          attach_company_verification_document(verification_ids) if verification_ids.any?
        end

        articles_file_ids = upload_documents_for('ARTICLES_OF_ASSOCIATION', 'account_requirement')
        if articles_file_ids.any?
          ::Stripe::Account.update(
            user.stripe_connect_account_id,
            documents: {
              company_memorandum_of_association: {
                files: articles_file_ids
              }
            }
          )
        end
      end

      def attach_individual_verification_document(proof_type, verification_key)
        file_ids = upload_documents_for(proof_type, 'identity_document', limit: 2)
        return if file_ids.empty?

        ::Stripe::Account.update(
          user.stripe_connect_account_id,
          individual: {
            verification: {
              verification_key => verification_file_payload(file_ids)
            }
          }
        )
      rescue ::Stripe::StripeError => e
        warnings << "Document #{proof_type} non synchronise vers Stripe: #{e.message}"
      end

      def attach_person_verification_document(proof_type, verification_key)
        return if representative_person.blank?

        file_ids = upload_documents_for(proof_type, 'identity_document', limit: 2)
        return if file_ids.empty?

        @representative_person = ::Stripe::Account.update_person(
          user.stripe_connect_account_id,
          representative_person.id,
          verification: {
            verification_key => verification_file_payload(file_ids)
          }
        )
      rescue ::Stripe::StripeError => e
        warnings << "Document representant #{proof_type} non synchronise vers Stripe: #{e.message}"
      end

      def attach_company_verification_document(file_ids)
        ::Stripe::Account.update(
          user.stripe_connect_account_id,
          company: {
            verification: {
              document: verification_file_payload(file_ids)
            }
          }
        )
      rescue ::Stripe::StripeError => e
        warnings << "Document entreprise non synchronise vers Stripe: #{e.message}"
      end

      def upload_documents_for(proof_type, purpose, limit: 10)
        documents_for_type(proof_type).first(limit).map do |document|
          upload_document_file(document, purpose)&.id
        end.compact
      end

      def upload_document_file(document, purpose)
        with_document_io(document) do |io|
          ::Stripe::File.create(
            { purpose: purpose, file: io },
            { stripe_account: user.stripe_connect_account_id }
          )
        end
      rescue ::Stripe::StripeError => e
        warnings << "Fichier #{proof_type_for(document)} non envoye a Stripe: #{e.message}"
        nil
      rescue => e
        warnings << "Fichier #{proof_type_for(document)} indisponible pour Stripe: #{e.message}"
        nil
      end

      def with_document_io(document)
        path = document.uploaded_image&.path
        if path.present? && ::File.exist?(path)
          return ::File.open(path, 'rb') { |file| yield file }
        end

        data = read_uploaded_file(document)
        unless data.present?
          warnings << "Fichier KYC #{proof_type_for(document)} introuvable localement ou sur le stockage distant."
          return nil
        end

        extension = ::File.extname(document.uploaded_image_identifier.to_s)
        temp_file = Tempfile.new(['stripe-kyc', extension])
        temp_file.binmode
        temp_file.write(data)
        temp_file.rewind
        yield temp_file
      ensure
        if temp_file
          temp_file.close
          temp_file.unlink
        end
      end

      def read_uploaded_file(document)
        stored_file = document.uploaded_image&.file
        if stored_file.respond_to?(:read)
          stored_file.rewind if stored_file.respond_to?(:rewind)
          return stored_file.read
        end

        url = document.uploaded_image&.url
        return nil if url.blank?

        URI.open(url, &:read)
      end

      def refresh_onboarding_flags!
        return if errors.any?

        user.stripe_onboarding_complete!(force_check: true)
      rescue => e
        warnings << "Verification finale Stripe non disponible: #{e.message}"
      end

      def verify_stripe_payout_ready!
        return if errors.any?

        account = ::Stripe::Account.retrieve(user.stripe_connect_account_id)
        return if account_ready_for_transfers?(account)

        due = account_requirements_due(account)
        disabled_reason = stripe_nested_value(account.requirements, :disabled_reason)
        details = []
        details << "exigences Stripe restantes: #{due.join(', ')}" if due.any?
        details << "raison Stripe: #{disabled_reason}" if disabled_reason.present?
        details << 'transfers capability inactive' unless stripe_capability(account, :transfers) == 'active'
        details << 'payouts_enabled=false' unless account.payouts_enabled

        errors << "Compte Stripe pas encore pret pour les virements (#{details.join('; ')})."
      rescue ::Stripe::StripeError => e
        errors << "Verification finale Stripe impossible: #{e.message}"
      end

      def stripe_account
        @stripe_account ||= ::Stripe::Account.retrieve(user.stripe_connect_account_id)
      end

      def account_ready_for_transfers?(account)
        account.payouts_enabled &&
          stripe_capability(account, :transfers) == 'active' &&
          account_requirements_due(account).empty?
      end

      def account_requirements_due(account)
        requirements = account.requirements
        (Array(stripe_nested_value(requirements, :currently_due)) + Array(stripe_nested_value(requirements, :past_due))).uniq
      end

      def stripe_capability(account, capability)
        stripe_nested_value(account.capabilities, capability)
      end

      def stripe_nested_value(object, key)
        return nil if object.blank?
        return object.public_send(key) if object.respond_to?(key)
        return object[key.to_s] if object.respond_to?(:[])

        nil
      rescue
        nil
      end

      def documents_for_type(proof_type)
        user.kycs.where(proof_type: proof_type.to_s)
                 .where.not(uploaded_image: [nil, ''])
                 .order(created_at: :desc)
                 .to_a
      end

      def verification_file_payload(file_ids)
        payload = { front: file_ids.first }
        payload[:back] = file_ids.second if file_ids.second.present?
        payload
      end

      def business_type
        user.profile_type == 'organization' ? 'company' : 'individual'
      end

      def business_profile_payload
        {
          name: bank_account_holder_name.to_s.truncate(100),
          product_description: 'Collecte de fonds via la plateforme Fiatope',
          url: ENV['FIATOPE_PUBLIC_URL'].presence || ENV['APP_HOST'].presence || PLATFORM_URL,
          support_email: ENV['EMAIL_CONTACT'].presence || 'contact@fiatope.com',
          support_phone: user.mobile_phone.to_s.presence
        }.compact
      end

      def company_payload
        payload = {
          name: user.organization&.name,
          phone: user.mobile_phone.to_s.presence,
          address: stripe_address_payload
        }

        if user.organization.respond_to?(:registration_number) && user.organization.registration_number.present?
          registration_number = user.organization.registration_number.to_s.strip.upcase
          payload[:registration_number] = registration_number
          payload[:tax_id] = registration_number if registration_number.match?(/\A\d{9}(\d{5})?\z/)
        end

        payload.compact
      end

      def bank_account_holder_name
        return user.organization.name if business_type == 'company' && user.organization&.name.present?

        user.name.to_s
      end

      def bank_country(bank_information)
        requested_country = bank_information.other_country.presence || user.residence_country.presence || 'FR'
        country_aligned_with_connect_account(requested_country)
      end

      def stripe_account_country
        return @stripe_account_country if defined?(@stripe_account_country)

        @stripe_account_country = stripe_account&.country.to_s.upcase.presence
      rescue ::Stripe::StripeError => e
        add_warning_once("Verification du pays du compte Stripe indisponible: #{e.message}")
        @stripe_account_country = nil
      end

      def country_aligned_with_connect_account(requested_country)
        requested = requested_country.to_s.upcase.presence || 'FR'
        account_country = stripe_account_country
        return requested if account_country.blank? || requested == account_country

        add_warning_once("Pays #{requested} ajuste en #{account_country} pour respecter le compte Stripe existant.")
        account_country
      end

      def tos_acceptance_payload
        return nil if tos_already_accepted?
        return nil unless @tos_accepted

        if request_ip.blank?
          errors << 'Adresse IP manquante: impossible d enregistrer l acceptation des conditions Stripe.'
          return nil
        end

        {
          date: Time.current.to_i,
          ip: request_ip,
          user_agent: user_agent.to_s.presence
        }.compact
      end

      def tos_already_accepted?
        tos = stripe_account.tos_acceptance
        stripe_nested_value(tos, :date).present? && stripe_nested_value(tos, :ip).present?
      rescue
        false
      end

      def add_warning_once(message)
        warnings << message unless warnings.include?(message)
      end

      def split_name(full_name)
        parts = full_name.to_s.strip.split(/\s+/)
        {
          first_name: parts.first,
          last_name: (parts[1..] || []).join(' ').presence || parts.first
        }
      end

      def individual_payload(name_parts)
        {
          first_name: name_parts[:first_name],
          last_name: name_parts[:last_name],
          email: user.email,
          phone: user.mobile_phone.to_s.presence,
          nationality: user.nationality.to_s.upcase.presence,
          address: stripe_address_payload,
          dob: stripe_dob_payload
        }.compact
      end

      def stripe_address_payload
        info = user.bank_information
        return nil if info.blank?

        requested_country = info.other_country.presence || user.residence_country.presence || 'FR'

        {
          line1: info.owner_address.to_s.presence,
          city: info.owner_city.to_s.presence,
          state: info.owner_region.to_s.presence,
          postal_code: info.owner_postal_code.to_s.presence,
          country: country_aligned_with_connect_account(requested_country)
        }.compact
      end

      def stripe_dob_payload
        return nil if user.birthday.blank?

        {
          day: user.birthday.day,
          month: user.birthday.month,
          year: user.birthday.year
        }
      end

      def proof_type_for(document)
        document&.proof_type.to_s.presence || 'KYC'
      end
    end
  end
end
