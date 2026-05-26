module Neighborly
  module Stripe
    class ConnectController < ApplicationController
      before_action :authenticate_user!
      before_action :clear_stale_flash

      rescue_from ActionDispatch::Cookies::CookieOverflow, with: :handle_cookie_overflow

      def create_account
        session[:stripe_return_to] = params[:return_to].presence

        sync_user_projects_on_return if current_user.stripe_connect_account_id.present?
        flash[:notice] = "Completez le profil de retrait depuis la page de votre projet pour activer les virements."
        redirect_to local_return_path
      end

      def refresh
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Vous devez d abord creer un compte de paiement."
          return redirect_to local_return_path
        end

        begin
          if current_user.stripe_onboarding_complete!(force_check: true)
            sync_user_projects_on_return
            flash[:notice] = "Votre compte de paiement est actif."
          else
            flash[:notice] = "Completez le profil de retrait sur Fiatope pour activer les virements."
          end
        rescue ::Stripe::StripeError => e
          Rails.logger.error "[Connect] refresh error: #{e.message}"
          flash[:alert] = "Erreur lors de la verification de votre compte."
        end

        redirect_to local_return_path
      end

      def return_url
        if current_user.stripe_connect_account_id.present?
          begin
            if current_user.stripe_onboarding_complete!(force_check: true)
              sync_user_projects_on_return
              flash[:notice] = I18n.t('stripe.onboarding.success', default: 'Votre compte de paiement est configure avec succes. Vos projets ont ete mis a jour.')
            else
              current_user.update(stripe_onboarding_complete: false)
              flash[:notice] = I18n.t('stripe.onboarding.incomplete', default: 'Informations enregistrees. Completez votre profil de retrait pour activer les virements.')
            end
          rescue ::Stripe::StripeError => e
            Rails.logger.error "[Connect] return error: #{e.message}"
            flash[:alert] = "Erreur lors de la verification de votre compte."
          end
        end

        return_to = session.delete(:stripe_return_to)
        if return_to.present? && return_to.start_with?('/')
          redirect_to return_to
        else
          redirect_to user_settings_path
        end
      end

      def dashboard
        flash[:notice] = I18n.t('stripe.dashboard.unavailable', default: 'Le retrait est suivi directement sur Fiatope. Vous n avez pas besoin d ouvrir Stripe.')
        redirect_to local_return_path
      end

      def link_existing_account
        if current_user.stripe_connect_account_id.present?
          flash[:notice] = "Vous avez deja un compte de paiement lie."
          redirect_to user_settings_path and return
        end

        account_id = params[:stripe_account_id].to_s.strip
        unless account_id.start_with?('acct_')
          flash[:alert] = "Format d ID invalide. L ID doit commencer par acct_."
          redirect_to user_settings_path and return
        end

        begin
          account = ::Stripe::Account.retrieve(account_id)
          unless platform_managed_account?(account)
            flash[:alert] = "Ce compte Stripe n est pas compatible avec le profil de retrait local. Utilisez un compte Custom gere par la plateforme."
            redirect_to user_settings_path and return
          end

          ready_for_transfers = account_ready_for_transfers?(account)
          update_attrs = {
            stripe_connect_account_id: account.id,
            stripe_onboarding_complete: ready_for_transfers
          }
          update_attrs[:stripe_account_type] = account.type if current_user.respond_to?(:stripe_account_type=)
          update_attrs[:stripe_charges_enabled] = account.charges_enabled if current_user.respond_to?(:stripe_charges_enabled=)
          update_attrs[:stripe_payouts_enabled] = account.payouts_enabled if current_user.respond_to?(:stripe_payouts_enabled=)

          current_user.update!(update_attrs)
          sync_user_projects_on_return

          Rails.logger.info "[Connect] Compte existant #{account.id} lie pour #{current_user.email}"

          if ready_for_transfers
            flash[:notice] = "Compte de paiement lie avec succes."
          else
            flash[:notice] = "Compte lie. Completez le profil de retrait pour activer les virements."
          end
        rescue ::Stripe::InvalidRequestError
          flash[:alert] = "Compte non trouve. Verifiez l identifiant."
        rescue ::Stripe::StripeError => e
          flash[:alert] = "Erreur de connexion: #{e.message}"
        rescue => e
          Rails.logger.error "Link existing error: #{e.message}"
          flash[:alert] = "Erreur: #{e.message}"
        end

        redirect_to user_settings_path
      end

      def find_existing_account
        account_id = params[:account_id].to_s.strip
        unless account_id.start_with?('acct_')
          render json: { error: "Format invalide" }, status: :unprocessable_entity and return
        end

        begin
          account = ::Stripe::Account.retrieve(account_id)
          render json: {
            found: true,
            account_id: account.id,
            type: account.type,
            charges_enabled: account.charges_enabled,
            payouts_enabled: account.payouts_enabled,
            managed_by_platform: platform_managed_account?(account),
            ready_for_transfers: account_ready_for_transfers?(account),
            country: account.country
          }
        rescue ::Stripe::InvalidRequestError
          render json: { found: false, error: "Compte non trouve" }
        rescue ::Stripe::StripeError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      def sync_account
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Aucun compte de paiement a synchroniser."
          return redirect_to user_settings_path
        end

        begin
          service = SyncService.new(current_user)
          if service.sync_all!
            n_proj = service.results[:projects].count
            n_cont = service.results[:contributions].count
            flash[:notice] = "Synchronisation OK: #{n_proj} projet(s), #{n_cont} contribution(s)."
          else
            err = service.errors.first.to_s.truncate(100)
            flash[:alert] = "Erreur sync: #{err}"
            Rails.logger.error "[Sync] #{service.errors.join(' | ')}"
          end
        rescue => e
          flash[:alert] = "Erreur: #{e.message.truncate(80)}"
          Rails.logger.error "[Sync] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        end

        redirect_to user_settings_path
      end

      def unlink_account
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Aucun compte de paiement a delier."
          return redirect_to user_settings_path
        end

        account_id = current_user.stripe_connect_account_id
        pending_transfers = current_user.projects
          .where(use_stripe: true)
          .joins(:contributions)
          .where(contributions: { payment_method: 'Stripe', state: 'confirmed', stripe_transferred: [false, nil] })
          .where.not(contributions: { stripe_charge_id: nil })
          .distinct
          .count

        if pending_transfers > 0
          flash[:alert] = "Impossible: #{pending_transfers} projet(s) ont des paiements non transferes."
          return redirect_to user_settings_path
        end

        current_user.projects.where(stripe_account_id: account_id).find_each do |project|
          project.update_columns(
            stripe_account_id: nil,
            use_stripe: false
          )
        end

        current_user.update_columns(
          stripe_connect_account_id: nil,
          stripe_onboarding_complete: false
        )

        Rails.logger.info "[Unlink] Compte #{account_id} delie pour #{current_user.email}"
        flash[:notice] = "Compte de paiement delie. Vos projets ne recevront plus de paiements."
        redirect_to user_settings_path
      end

      private

      def user_settings_path
        "/neighbors/#{current_user.id}/settings"
      end

      def local_return_path
        return_to = session.delete(:stripe_return_to)
        return return_to if return_to.present? && return_to.start_with?('/')

        user_settings_path
      end

      def clear_stale_flash
        flash.clear
      end

      def handle_cookie_overflow
        Rails.logger.warn "[CookieOverflow] Session trop large pour #{current_user&.email}, nettoyage"
        reset_session
        redirect_to user_settings_path
      end

      def sync_user_projects_on_return
        return unless current_user.stripe_connect_account_id.present?

        synced = 0
        current_user.projects.find_each do |project|
          if project.stripe_account_id != current_user.stripe_connect_account_id
            project.update_columns(
              stripe_account_id: current_user.stripe_connect_account_id,
              use_stripe: true
            )
            synced += 1
          end
        end

        Rails.logger.info "Connect Return: Synchronise #{synced} projet(s) pour #{current_user.email}"
      end

      def platform_managed_account?(account)
        account.type == 'custom' || stripe_nested_value(account.controller, :requirement_collection) == 'application'
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
    end
  end
end
