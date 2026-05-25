module Neighborly
  module Stripe
    class SyncService
      attr_reader :user, :results, :errors

      def initialize(user)
        @user = user
        @results = { user: nil, projects: [], contributions: [] }
        @errors = []
      end

      def sync_all!
        return false unless user.stripe_connect_account_id.present?

        begin
          sync_user_account!
          sync_projects!
          sync_contributions!

          Rails.logger.info "[SyncService] Sync complete pour #{user.email}: #{summary}"
          true
        rescue ::Stripe::StripeError => e
          @errors << "Erreur Stripe: #{e.message}"
          Rails.logger.error "[SyncService] Erreur Stripe: #{e.message}"
          false
        rescue => e
          @errors << "Erreur: #{e.message}"
          Rails.logger.error "[SyncService] Erreur: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          false
        end
      end

      def summary
        "User: #{@results[:user] ? 'OK' : 'KO'}, " \
          "Projets: #{@results[:projects].count}, " \
          "Contributions: #{@results[:contributions].count}, " \
          "Erreurs: #{@errors.count}"
      end

      private

      def sync_user_account!
        account = ::Stripe::Account.retrieve(user.stripe_connect_account_id)
        ready_for_transfers = account_ready_for_transfers?(account)
        updates = { stripe_onboarding_complete: ready_for_transfers }

        if user.respond_to?(:stripe_account_type=)
          updates[:stripe_account_type] = account.type
        end
        if user.respond_to?(:stripe_charges_enabled=)
          updates[:stripe_charges_enabled] = account.charges_enabled
        end
        if user.respond_to?(:stripe_payouts_enabled=)
          updates[:stripe_payouts_enabled] = account.payouts_enabled
        end

        user.update_columns(updates) if updates.any?

        @results[:user] = {
          account_id: account.id,
          business_type: account.business_type,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          transfers_capability: stripe_nested_value(account.capabilities, :transfers),
          details_submitted: account.details_submitted,
          requirements_due: account_requirements_due(account),
          email: account.email
        }
      end

      def account_ready_for_transfers?(account)
        account.payouts_enabled &&
          stripe_nested_value(account.capabilities, :transfers) == 'active' &&
          account_requirements_due(account).empty?
      end

      def account_requirements_due(account)
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

      def sync_projects!
        user.projects.find_each do |project|
          sync_project!(project)
        end
      end

      def sync_project!(project)
        updates = {}
        updates[:stripe_account_id] = user.stripe_connect_account_id if project.stripe_account_id != user.stripe_connect_account_id
        updates[:use_stripe] = true unless project.use_stripe?

        project.update_columns(updates) if updates.any?

        @results[:projects] << {
          id: project.id,
          name: project.name,
          updated: updates.any?,
          changes: updates
        }
      end

      def sync_contributions!
        user.projects.find_each do |project|
          sync_project_contributions!(project)
        end
      end

      def sync_project_contributions!(project)
        contributions = project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
        contributions.find_each do |contribution|
          sync_contribution!(contribution)
        end
      end

      def sync_contribution!(contribution)
        return unless contribution.payment_id.present?

        updates = {}
        payment_intent_id = contribution.payment_id

        begin
          payment_intent = ::Stripe::PaymentIntent.retrieve(payment_intent_id)
          charge_ref = payment_intent.try(:latest_charge)
          charge_ref ||= payment_intent.charges&.data&.first&.id rescue nil

          if charge_ref.present?
            charge_id = charge_ref.is_a?(String) ? charge_ref : (charge_ref.try(:id) || charge_ref.to_s)
            charge = ::Stripe::Charge.retrieve(charge_id)

            updates[:stripe_charge_id] = charge.id if contribution.stripe_charge_id.blank? && charge.id.present?
            updates[:stripe_refunded] = true if charge.refunded && !contribution.stripe_refunded

            transfer_id = charge['transfer']
            if transfer_id.present? && !contribution.stripe_transferred
              updates[:stripe_transferred] = true
              updates[:stripe_transfer_id] = transfer_id if contribution.stripe_transfer_id.blank?
            end
          end

          contribution.update_columns(updates) if updates.any?

          @results[:contributions] << {
            id: contribution.id,
            payment_id: payment_intent_id,
            updated: updates.any?
          }
        rescue ::Stripe::InvalidRequestError => e
          @errors << "Contribution #{contribution.id}: #{e.message.truncate(80)}"
        rescue => e
          @errors << "Contribution #{contribution.id}: #{e.message.truncate(80)}"
        end
      end

      class << self
        def sync_all_users!
          results = { success: 0, failed: 0, errors: [] }

          ::User.where.not(stripe_connect_account_id: nil).find_each do |user|
            service = new(user)
            if service.sync_all!
              results[:success] += 1
            else
              results[:failed] += 1
              results[:errors] += service.errors
            end
          end

          results
        end

        def sync_project!(project)
          return { success: false, error: "Projet sans porteur" } unless project.user
          return { success: false, error: "Porteur sans compte Stripe" } unless project.user.stripe_connect_account_id

          service = new(project.user)
          service.sync_all!

          {
            success: service.errors.empty?,
            results: service.results,
            errors: service.errors
          }
        end
      end
    end
  end
end
