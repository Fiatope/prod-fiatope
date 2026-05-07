module Neighborly
  module Stripe
    class PayoutProfileSyncService < ApplicationService
      Result = Struct.new(:success, :errors, :warnings, keyword_init: true) do
        def success?
          success
        end
      end

      def initialize(user)
        @user = user
        @errors = []
        @warnings = []
      end

      def call
        unless stripe_configured?
          warnings << 'Configuration Stripe absente sur cet environnement.'
          return Result.new(success: true, errors: errors, warnings: warnings)
        end

        unless user.payout_profile_complete?
          errors << 'Profil de retrait incomplet.'
          return Result.new(success: false, errors: errors, warnings: warnings)
        end

        ensure_connect_account!
        sync_account_identity!
        sync_bank_account!
        sync_kyc_document!
        refresh_onboarding_flags!

        Result.new(success: errors.empty?, errors: errors, warnings: warnings)
      rescue ::Stripe::StripeError => e
        errors << "Stripe API: #{e.message}"
        Result.new(success: false, errors: errors, warnings: warnings)
      rescue => e
        errors << e.message
        Result.new(success: false, errors: errors, warnings: warnings)
      end

      private

      attr_reader :user, :errors, :warnings

      def stripe_configured?
        ENV['STRIPE_SECRET_KEY'].present?
      end

      def ensure_connect_account!
        return if user.stripe_connect_account_id.present?

        user.create_stripe_connect_account!
      rescue ::Stripe::StripeError => e
        errors << "Creation du compte Stripe impossible: #{e.message}"
      end

      def sync_account_identity!
        return if errors.any?

        name_parts = split_name(user.name)
        account_params = {
          business_type: business_type,
          email: user.email,
          metadata: {
            platform: 'fiatope',
            user_id: user.id.to_s,
            profile_type: user.profile_type.to_s,
            payout_profile_complete: user.payout_profile_complete?.to_s
          }
        }

        if business_type == 'company'
          account_params[:company] = {
            name: user.organization&.name,
            tax_id_provided: false
          }.compact
          account_params[:individual] = individual_payload(name_parts)
        else
          account_params[:individual] = individual_payload(name_parts)
        end

        ::Stripe::Account.update(user.stripe_connect_account_id, account_params)
      rescue ::Stripe::StripeError => e
        errors << "Synchronisation identite Stripe impossible: #{e.message}"
      end

      def sync_bank_account!
        return if errors.any?

        info = user.bank_information
        return if info.blank?

        reference_type = info.payout_bank_reference_type
        reference_value = info.payout_bank_reference_value.to_s
        return if reference_value.blank?

        unless reference_type == 'iban'
          warnings << "Reference bancaire #{reference_type.to_s.upcase} enregistree localement. Synchronisation Stripe automatique ignoree (IBAN requis)."
          return
        end

        token = ::Stripe::Token.create(
          bank_account: {
            country: bank_country(info),
            currency: 'eur',
            account_holder_name: user.name.to_s,
            account_holder_type: business_type,
            account_number: reference_value
          }
        )

        account = ::Stripe::Account.retrieve(user.stripe_connect_account_id)
        existing_bank_account = account.external_accounts&.data&.find { |external| external.object == 'bank_account' }

        if existing_bank_account
          begin
            ::Stripe::Account.update_external_account(
              user.stripe_connect_account_id,
              existing_bank_account.id,
              external_account: token.id
            )
          rescue ::Stripe::StripeError
            ::Stripe::Account.create_external_account(user.stripe_connect_account_id, external_account: token.id)
          end
        else
          ::Stripe::Account.create_external_account(user.stripe_connect_account_id, external_account: token.id)
        end
      rescue ::Stripe::StripeError => e
        errors << "Synchronisation bancaire Stripe impossible: #{e.message}"
      end

      def sync_kyc_document!
        return if errors.any?

        latest_document = latest_kyc_document
        return if latest_document.blank?

        path = latest_document.uploaded_image&.path
        unless path.present? && File.exist?(path)
          warnings << 'Fichier KYC introuvable localement pour la synchronisation Stripe.'
          return
        end

        stripe_file = ::Stripe::File.create(
          purpose: 'identity_document',
          file: File.new(path)
        )

        if business_type == 'company'
          ::Stripe::Account.update(
            user.stripe_connect_account_id,
            company: {
              verification: {
                document: {
                  front: stripe_file.id
                }
              }
            }
          )
        else
          ::Stripe::Account.update(
            user.stripe_connect_account_id,
            individual: {
              verification: {
                document: {
                  front: stripe_file.id
                }
              }
            }
          )
        end
      rescue ::Stripe::StripeError => e
        warnings << "Document KYC non synchronise vers Stripe: #{e.message}"
      end

      def refresh_onboarding_flags!
        user.stripe_onboarding_complete!(force_check: true)
      rescue => e
        warnings << "Verification finale Stripe non disponible: #{e.message}"
      end

      def latest_kyc_document
        required_types = user.payout_profile_required_kyc_types
        user.kycs.where(proof_type: required_types).where.not(uploaded_image: [nil, '']).order(created_at: :desc).first
      end

      def business_type
        user.profile_type == 'organization' ? 'company' : 'individual'
      end

      def bank_country(bank_information)
        bank_information.other_country.presence || user.residence_country.presence || 'FR'
      end

      def split_name(full_name)
        parts = full_name.to_s.strip.split(/\s+/)
        {
          first_name: parts.first,
          last_name: (parts[1..] || []).join(' ').presence || parts.first
        }
      end

      def individual_payload(name_parts)
        payload = {
          first_name: name_parts[:first_name],
          last_name: name_parts[:last_name],
          nationality: user.nationality.to_s.upcase.presence,
          address: stripe_address_payload,
          dob: stripe_dob_payload
        }

        payload.compact
      end

      def stripe_address_payload
        info = user.bank_information
        return nil if info.blank?

        {
          line1: info.owner_address.to_s.presence,
          city: info.owner_city.to_s.presence,
          state: info.owner_region.to_s.presence,
          postal_code: info.owner_postal_code.to_s.presence,
          country: bank_country(info)
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
    end
  end
end
