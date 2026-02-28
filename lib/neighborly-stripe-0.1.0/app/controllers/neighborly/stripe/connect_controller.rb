module Neighborly
  module Stripe
    class ConnectController < ApplicationController
      before_action :authenticate_user!
      before_action :clear_stale_flash
      
      rescue_from ActionDispatch::Cookies::CookieOverflow, with: :handle_cookie_overflow
      
      def create_account
        if current_user.stripe_connect_account_id.blank?
          current_user.create_stripe_connect_account!
        end
        
        redirect_url = current_user.stripe_account_onboarding_url(
          refresh_url: "#{request.base_url}/stripe/connect/refresh",
          return_url: "#{request.base_url}/stripe/connect/return"
        )
        
        redirect_to redirect_url, allow_other_host: true
      end
      
      def refresh
        redirect_url = current_user.stripe_account_onboarding_url(
          refresh_url: "#{request.base_url}/stripe/connect/refresh",
          return_url: "#{request.base_url}/stripe/connect/return"
        )
        
        redirect_to redirect_url, allow_other_host: true
      end
      
      def return_url
        if current_user.stripe_onboarding_complete?
          # CRITIQUE: Synchroniser tous les projets du porteur
          sync_user_projects_on_return
          
          flash[:notice] = I18n.t('stripe.onboarding.success', default: 'Votre compte Stripe est configuré avec succès ! Vos projets ont été mis à jour.')
          redirect_to user_settings_path
        else
          flash[:alert] = I18n.t('stripe.onboarding.incomplete', default: 'Veuillez compléter votre profil Stripe')
          redirect_to user_settings_path
        end
      end
      
      def dashboard
        dashboard_url = current_user.stripe_dashboard_url
        
        if dashboard_url
          redirect_to dashboard_url, allow_other_host: true
        else
          flash[:alert] = I18n.t('stripe.dashboard.unavailable', default: 'Dashboard Stripe non disponible')
          redirect_to request.referer || "/"
        end
      end
      
      # POST /stripe/connect/link_existing
      def link_existing_account
        if current_user.stripe_connect_account_id.present?
          flash[:notice] = "Vous avez d\u00e9j\u00e0 un compte de paiement li\u00e9."
          redirect_to user_settings_path and return
        end
        
        account_id = params[:stripe_account_id].to_s.strip
        
        unless account_id.start_with?('acct_')
          flash[:alert] = "Format d'ID invalide. L'ID doit commencer par 'acct_'"
          redirect_to user_settings_path and return
        end
        
        begin
          account = ::Stripe::Account.retrieve(account_id)
          
          # Mise à jour avec uniquement les colonnes qui existent
          update_attrs = {
            stripe_connect_account_id: account.id,
            stripe_onboarding_complete: account.charges_enabled && account.payouts_enabled
          }
          
          # Ajouter les colonnes optionnelles si elles existent
          if current_user.respond_to?(:stripe_account_type=)
            update_attrs[:stripe_account_type] = account.type
          end
          if current_user.respond_to?(:stripe_charges_enabled=)
            update_attrs[:stripe_charges_enabled] = account.charges_enabled
          end
          if current_user.respond_to?(:stripe_payouts_enabled=)
            update_attrs[:stripe_payouts_enabled] = account.payouts_enabled
          end
          
          current_user.update!(update_attrs)
          sync_user_projects_on_return
          
          Rails.logger.info "[Connect] Compte existant #{account.id} li\u00e9 pour #{current_user.email}"
          
          if account.charges_enabled && account.payouts_enabled
            flash[:notice] = "Compte de paiement li\u00e9 avec succ\u00e8s !"
          else
            flash[:notice] = "Compte lié. Complétez l'onboarding pour activer les paiements."
            redirect_url = current_user.stripe_account_onboarding_url(
              refresh_url: "#{request.base_url}/stripe/connect/refresh",
              return_url: "#{request.base_url}/stripe/connect/return"
            )
            redirect_to redirect_url, allow_other_host: true and return
          end
          
        rescue ::Stripe::InvalidRequestError => e
          flash[:alert] = "Compte Stripe non trouvé. Vérifiez l'ID."
        rescue ::Stripe::StripeError => e
          flash[:alert] = "Erreur Stripe: #{e.message}"
        rescue => e
          Rails.logger.error "Link existing error: #{e.message}"
          flash[:alert] = "Erreur: #{e.message}"
        end
        
        redirect_to user_settings_path
      end
      
      # GET /stripe/connect/find_existing - Vérifie un compte par ID
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
            country: account.country
          }
        rescue ::Stripe::InvalidRequestError
          render json: { found: false, error: "Compte non trouvé" }
        rescue ::Stripe::StripeError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      # POST /stripe/connect/sync
      def sync_account
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Aucun compte de paiement \u00e0 synchroniser."
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
      
      # POST /stripe/connect/unlink
      def unlink_account
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Aucun compte de paiement \u00e0 d\u00e9lier."
          return redirect_to user_settings_path
        end
        
        account_id = current_user.stripe_connect_account_id
        
        # Vérifier qu'il n'y a pas de transferts en cours
        pending_transfers = current_user.projects
          .where(use_stripe: true)
          .joins(:contributions)
          .where(contributions: { payment_method: 'Stripe', state: 'confirmed', stripe_transferred: [false, nil] })
          .where.not(contributions: { stripe_charge_id: nil })
          .distinct
          .count
        
        if pending_transfers > 0
          flash[:alert] = "Impossible: #{pending_transfers} projet(s) ont des paiements non transf\u00e9r\u00e9s."
          return redirect_to user_settings_path
        end
        
        # Délier le compte de tous les projets
        current_user.projects.where(stripe_account_id: account_id).find_each do |project|
          project.update_columns(
            stripe_account_id: nil,
            use_stripe: false
          )
        end
        
        # Délier le compte de l'utilisateur
        current_user.update_columns(
          stripe_connect_account_id: nil,
          stripe_onboarding_complete: false
        )
        
        Rails.logger.info "[Unlink] Compte #{account_id} d\u00e9li\u00e9 pour #{current_user.email}"
        flash[:notice] = "Compte de paiement d\u00e9li\u00e9. Vos projets ne recevront plus de paiements."
        redirect_to user_settings_path
      end
      
      private
      
      def user_settings_path
        "/neighbors/#{current_user.id}/settings"
      end
      
      # Vider les anciens flash pour \u00e9viter accumulation → CookieOverflow
      def clear_stale_flash
        flash.clear
      end
      
      # Rescue CookieOverflow: rediriger proprement sans flash
      def handle_cookie_overflow
        Rails.logger.warn "[CookieOverflow] Session trop large pour #{current_user&.email}, nettoyage"
        reset_session
        redirect_to user_settings_path
      end
      
      # Synchronise tous les projets du porteur quand il revient de l'onboarding
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
        
        Rails.logger.info "Connect Return: Synchronisé #{synced} projet(s) pour #{current_user.email}"
      end
    end
  end
end
