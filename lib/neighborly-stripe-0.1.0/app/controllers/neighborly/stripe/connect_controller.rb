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
        flash[:notice] = I18n.t('stripe.dashboard.unavailable', default: 'Le retrait est suivi directement sur Fiatope. Vous n avez pas besoin de quitter la plateforme.')
        redirect_to local_return_path
      end

      def link_existing_account
        Rails.logger.info "[Connect] Liaison manuelle refusee pour #{current_user.email}"
        flash[:alert] = "Cette action n est plus disponible. Completez le profil de retrait depuis la page de votre projet."
        redirect_to user_settings_path
      end

      def find_existing_account
        Rails.logger.info "[Connect] Recherche de compte manuelle refusee pour #{current_user.email}"
        render json: { error: "Action indisponible" }, status: :forbidden
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
            flash[:notice] = "La verification du compte de paiement a ete relancee pour #{n_proj} projet(s)."
          else
            Rails.logger.error "[Sync] #{service.errors.join(' | ')}"
            flash[:alert] = "La verification n a pas abouti. Veuillez reessayer plus tard ou contacter l equipe support."
          end
        rescue => e
          Rails.logger.error "[Sync] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
          flash[:alert] = "La verification n a pas abouti. Veuillez reessayer plus tard ou contacter l equipe support."
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

        locked_projects = current_user.projects.where(stripe_account_id: account_id).to_a.select { |project| stripe_project_account_locked?(project) }
        if locked_projects.any?
          flash[:alert] = "Impossible: #{locked_projects.count} projet(s) ont un retrait en cours ou deja confirme. Contactez l equipe support."
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
        skipped = 0
        current_user.projects.find_each do |project|
          if stripe_project_account_locked?(project)
            skipped += 1
            next
          end

          if project.stripe_account_id != current_user.stripe_connect_account_id
            project.update_columns(
              stripe_account_id: current_user.stripe_connect_account_id,
              use_stripe: true
            )
            synced += 1
          end
        end

        Rails.logger.info "Connect Return: Synchronise #{synced} projet(s) pour #{current_user.email}; #{skipped} projet(s) deja en reglement ignores"
      end

      def stripe_project_account_locked?(project)
        settlement_type = project.respond_to?(:stripe_settlement_type) ? project.stripe_settlement_type.to_s : ''
        payout_status = project.respond_to?(:stripe_payout_status) ? project.stripe_payout_status.to_s : ''
        payout_id = project.respond_to?(:stripe_payout_id) ? project.stripe_payout_id : nil

        settlement_type == 'transferred' ||
          payout_id.present? ||
          %w[pending in_transit paid failed canceled].include?(payout_status)
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
    end
  end
end
