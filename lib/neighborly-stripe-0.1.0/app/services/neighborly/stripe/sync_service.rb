module Neighborly
  module Stripe
    class SyncService
      attr_reader :user, :results, :errors
      
      def initialize(user)
        @user = user
        @results = { user: nil, projects: [], contributions: [] }
        @errors = []
      end
      
      # Synchronisation complète: récupère tout depuis Stripe
      def sync_all!
        return false unless user.stripe_connect_account_id.present?
        
        begin
          # 1. Sync infos compte Stripe du porteur
          sync_user_account!
          
          # 2. Sync tous les projets du porteur
          sync_projects!
          
          # 3. Sync les contributions Stripe de chaque projet
          sync_contributions!
          
          Rails.logger.info "[SyncService] Sync complète pour #{user.email}: #{summary}"
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
        "User: #{@results[:user] ? '✓' : '✗'}, " \
        "Projets: #{@results[:projects].count}, " \
        "Contributions: #{@results[:contributions].count}, " \
        "Erreurs: #{@errors.count}"
      end
      
      private
      
      # Récupère les infos du compte Stripe Connect
      def sync_user_account!
        account = ::Stripe::Account.retrieve(user.stripe_connect_account_id)
        
        updates = {}
        
        # Vérifier si onboarding complet
        if account.charges_enabled && account.payouts_enabled
          updates[:stripe_onboarding_complete] = true
        else
          updates[:stripe_onboarding_complete] = false
        end
        
        # Mettre à jour le user si nécessaire
        if updates.any? && updates.values != [user.stripe_onboarding_complete]
          user.update_columns(updates)
        end
        
        @results[:user] = {
          account_id: account.id,
          business_type: account.business_type,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          details_submitted: account.details_submitted,
          email: account.email
        }
      end
      
      # Synchronise tous les projets du porteur
      def sync_projects!
        user.projects.find_each do |project|
          sync_project!(project)
        end
      end
      
      def sync_project!(project)
        updates = {}
        
        # S'assurer que le projet a le bon stripe_account_id
        if project.stripe_account_id != user.stripe_connect_account_id
          updates[:stripe_account_id] = user.stripe_connect_account_id
        end
        
        # Activer Stripe si pas encore fait
        unless project.use_stripe?
          updates[:use_stripe] = true
        end
        
        if updates.any?
          project.update_columns(updates)
        end
        
        @results[:projects] << {
          id: project.id,
          name: project.name,
          updated: updates.any?,
          changes: updates
        }
      end
      
      # Synchronise les contributions Stripe
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
          # Récupérer le PaymentIntent depuis Stripe
          payment_intent = ::Stripe::PaymentIntent.retrieve(payment_intent_id)
          
          # Vérifier les charges associées
          if payment_intent.latest_charge.present?
            charge = ::Stripe::Charge.retrieve(payment_intent.latest_charge)
            
            # Vérifier si remboursé
            if charge.refunded
              unless contribution.stripe_refunded
                updates[:stripe_refunded] = true
                updates[:stripe_refunded_at] = Time.current
              end
            end
            
            # Vérifier les transferts
            if charge.transfer.present?
              unless contribution.stripe_transferred
                updates[:stripe_transferred] = true
                updates[:stripe_transferred_at] = Time.current
              end
            end
          end
          
          if updates.any?
            contribution.update_columns(updates)
          end
          
          @results[:contributions] << {
            id: contribution.id,
            payment_id: payment_intent_id,
            updated: updates.any?,
            changes: updates
          }
        rescue ::Stripe::InvalidRequestError => e
          # PaymentIntent non trouvé - ignorer
          @errors << "Contribution #{contribution.id}: #{e.message}"
        end
      end
      
      # === Méthodes de classe pour sync en masse ===
      
      class << self
        # Sync tous les utilisateurs avec un compte Stripe
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
        
        # Sync un projet et ses contributions
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
