module Neighborly
  module Stripe
    class ConnectController < ApplicationController
      before_action :authenticate_user!
      
      def create_account
        if current_user.stripe_connect_account_id.blank?
          current_user.create_stripe_connect_account!
        end
        
        # Mémoriser la page de retour après onboarding (ex: page pay d'un projet)
        session[:stripe_onboarding_return_to] = params[:return_to] || request.referer
        
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
          sync_user_projects_on_return
          
          flash[:notice] = I18n.t('stripe.onboarding.success',
            default: 'Votre compte Stripe est configuré avec succès ! Vous pouvez maintenant retirer vos fonds.')
          
          # Rediriger vers la page de retrait du projet si elle a été mémorisée
          return_to = session.delete(:stripe_onboarding_return_to)
          if return_to.present?
            redirect_to return_to
          else
            # Par défaut: aller vers le premier projet actif du porteur s'il en a un
            first_project = current_user.projects.where(use_stripe: true).first
            if first_project
              redirect_to "/projects/#{first_project.permalink}/pay"
            else
              redirect_to "/users/#{current_user.id}/edit#settings"
            end
          end
        else
          flash[:alert] = I18n.t('stripe.onboarding.incomplete',
            default: 'Veuillez compléter votre profil Stripe pour pouvoir recevoir vos fonds.')
          redirect_to "/users/#{current_user.id}/edit#settings"
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
      # Lie un compte Stripe Connect existant (créé sur une autre plateforme)
      def link_existing_account
        if current_user.stripe_connect_account_id.present?
          flash[:notice] = "Vous avez déjà un compte Stripe Connect lié"
          redirect_to "/users/#{current_user.id}/edit#settings" and return
        end
        
        account_id = params[:stripe_account_id].to_s.strip
        
        unless account_id.start_with?('acct_')
          flash[:alert] = "Format d'ID invalide. L'ID doit commencer par 'acct_'"
          redirect_to "/users/#{current_user.id}/edit#settings" and return
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
          
          Rails.logger.info "Stripe Connect: Compte existant #{account.id} lié pour #{current_user.email}"
          
          if account.charges_enabled && account.payouts_enabled
            flash[:notice] = "✅ Compte Stripe Connect lié avec succès ! Vous pouvez recevoir des paiements."
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
        
        redirect_to "/users/#{current_user.id}/edit#settings"
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
      
      # Synchronisation COMPLÈTE depuis l'API Stripe
      def sync_account
        unless current_user.stripe_connect_account_id.present?
          flash[:alert] = "Vous n'avez pas encore de compte Stripe Connect."
          return redirect_back(fallback_location: "/users/#{current_user.id}/edit")
        end
        
        begin
          service = SyncService.new(current_user)
          
          if service.sync_all!
            results = service.results
            flash[:success] = "✅ Synchronisation complète! " \
              "#{results[:projects].count} projet(s), " \
              "#{results[:contributions].count} contribution(s) vérifiée(s)."
          else
            flash[:alert] = "Erreur: #{service.errors.join(', ')}"
          end
        rescue => e
          flash[:alert] = "Erreur: #{e.message}"
          Rails.logger.error "[SyncAccount] Error: #{e.message}"
        end
        
        redirect_back(fallback_location: "/users/#{current_user.id}/edit")
      end
      
      private
      
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
