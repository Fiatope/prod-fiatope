module Neighborly
  module Stripe
    class ConnectController < ApplicationController
      before_action :authenticate_user!
      
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
          redirect_to "/users/#{current_user.id}/edit#settings"
        else
          flash[:alert] = I18n.t('stripe.onboarding.incomplete', default: 'Veuillez compléter votre profil Stripe')
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
      
      # Synchronisation COMPLÈTE depuis l'API Stripe
      # Récupère: infos compte, projets, contributions (transferts, remboursements)
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
