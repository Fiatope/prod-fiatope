module Neighborly::Admin
  class ProjectsController < BaseController
    defaults finder: :find_by_permalink!

    has_scope :by_user_email, :by_id, :pg_search, :user_name_contains, :with_state, :by_category_id, :order_by
    has_scope :between_created_at, :between_expires_at, :between_online_date, :between_updated_at, :goal_between, using: [ :start_at, :ends_at ]

    before_action do
      @total_projects = Project.count
    end

    [:launch, :reject, :push_to_draft, :push_to_request_funds, :push_to_fraud_suspiscion, :push_to_paid, :approve].each do |name|
      define_method name do
        @project = Project.find_by_permalink params[:id]
        @project.send("#{name.to_s}!")
        redirect_back(fallback_location: root_path)
      end
    end

    def show_project_on_homepage
      @projects_show_on_homepage = Project.projects_to_show_on_home_page.count

      if @projects_show_on_homepage == 3
        flash[:alert] = "Trois cagnottes on été déja mis en page d'accueil!"
      elsif @projects_show_on_homepage < 3
        @project = Project.find_by(permalink: params[:id])

        if @project.present?
          @project.show_on_homepage = true
          @project.save

          flash[:success] = "Success!"
        else
          flash[:error] = "Projet introuvable!"
        end
      end

      redirect_back(fallback_location: root_path)
    end

    def remove_project_on_homepage
      @project = Project.find_by(permalink: params[:id])

      if @project.present?
        if @project.show_on_homepage
          @project.show_on_homepage = false
          @project.save

          flash[:success] = "Success!"
        end
      else
        flash[:error] = "Projet introuvable!"
      end

      redirect_back(fallback_location: root_path)
    end

    def populate
      if params[:user][:id].present?
        @user = User.find(params[:user][:id])
      else
        @user = create_user
      end

      @contribution = build_contribution(@user)

      if @user.valid? and @contribution.valid?
        @user.save!
        @contribution.save!
        redirect_to populate_contribution_project_path(resource), flash: { success: 'Success!' }
      else
        flash.alert = (@user.errors.full_messages +
                       @contribution.errors.full_messages).to_sentence
        render :populate_contribution
      end
    end

    def destroy
      resource.push_to_trash! if resource.can_push_to_trash?
      redirect_to projects_path
    end
    
    # === ACTIONS STRIPE ===
    
    # Synchronisation COMPLÈTE depuis Stripe API
    # Récupère: infos compte, projets, contributions (transferts, remboursements)
    def sync_stripe_account
      @project = Project.find_by_permalink params[:id]
      
      unless @project.user.stripe_connect_account_id.present?
        flash[:alert] = "Le porteur #{@project.user.name} n'a pas encore de compte Stripe Connect."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        service = Neighborly::Stripe::SyncService.new(@project.user)
        
        if service.sync_all!
          results = service.results
          flash[:success] = "✅ Synchronisation complète! " \
            "Compte: #{results[:user][:charges_enabled] ? 'Actif' : 'En attente'}, " \
            "#{results[:projects].count} projet(s), " \
            "#{results[:contributions].count} contribution(s) vérifiée(s)."
        else
          flash[:alert] = "Erreur: #{service.errors.join(', ')}"
        end
      rescue => e
        flash[:alert] = "Erreur: #{e.message}"
        Rails.logger.error "[Admin] Sync error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Active Stripe pour un projet et crée/réutilise le compte connecté du porteur
    def enable_stripe
      @project = Project.find_by_permalink params[:id]
      
      if @project.use_stripe?
        # Forcer la synchronisation même si Stripe est déjà activé
        if @project.user.stripe_connect_account_id.present?
          synced = @project.sync_all_user_projects!
          flash[:notice] = "Compte Stripe synchronisé (#{synced} projet(s) mis à jour)."
        else
          flash[:notice] = "Stripe est déjà activé pour ce projet."
        end
      else
        begin
          # enable_stripe! réutilise le compte existant ou en crée un nouveau
          @project.enable_stripe!
          
          if @project.user.stripe_onboarding_complete?
            flash[:success] = "Stripe activé! Le porteur a déjà un compte configuré - prêt pour les paiements."
          else
            flash[:success] = "Stripe activé! Le porteur doit compléter son profil Stripe (générer un lien d'onboarding)."
          end
        rescue => e
          flash[:alert] = "Erreur lors de l'activation de Stripe: #{e.message}"
        end
      end
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Génère le lien d'onboarding Stripe pour le porteur
    def stripe_onboarding_link
      @project = Project.find_by_permalink params[:id]
      
      unless @project.use_stripe?
        flash[:alert] = "Stripe n'est pas activé pour ce projet. Activez-le d'abord."
        return redirect_back(fallback_location: projects_path)
      end
      
      if @project.user.stripe_onboarding_complete?
        flash[:notice] = "Le porteur a déjà complété son profil Stripe. Pas besoin de lien d'onboarding."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        base_url = request.base_url
        onboarding_url = @project.user.stripe_account_onboarding_url(
          refresh_url: "#{base_url}/stripe/connect/refresh",
          return_url: "#{base_url}/stripe/connect/return"
        )
        
        flash[:stripe_onboarding_url] = onboarding_url
        flash[:success] = "Lien généré pour #{@project.user.name}. Envoyez-le par email."
      rescue => e
        flash[:alert] = "Erreur: #{e.message}"
      end
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Transfère les fonds au porteur (peu importe si objectif atteint ou non)
    # On transfère ce qu'on a collecté au porteur
    def process_stripe_transfer
      @project = Project.find_by_permalink params[:id]
      
      unless @project.use_stripe?
        flash[:alert] = "Stripe n'est pas activé pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      unless @project.user.stripe_onboarding_complete?
        flash[:alert] = "Le porteur n'a pas complété son profil Stripe. Générez un lien d'onboarding."
        return redirect_back(fallback_location: projects_path)
      end
      
      if @project.stripe_settlement_type == 'transferred'
        flash[:notice] = "Les fonds ont déjà été transférés au porteur."
        return redirect_back(fallback_location: projects_path)
      end
      
      # Vérifier qu'il y a des contributions à transférer
      contributions = @project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                              .where(stripe_refunded: [false, nil])
      if contributions.empty?
        flash[:alert] = "Aucune contribution Stripe à transférer."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        settlement = Neighborly::Stripe::CampaignSettlement.new(@project)
        
        if settlement.process!
          total = contributions.sum(:value)
          fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').to_f / 100
          net = (total * (1 - fee_pct)).round(2)
          
          # FLUX CROWDFUNDING: après transfert réussi → projet passe en 'paid'
          # request_funds → paid (porteur a demandé, admin a transféré)
          if @project.can_push_to_paid?
            @project.push_to_paid!
            Rails.logger.info "[Admin] Projet #{@project.id} passé en état 'paid' après transfert Stripe"
          end
          
          if settlement.errors.any?
            flash[:success] = "✅ Transfert de #{net}€ effectué avec avertissements: #{settlement.errors.join(', ')}"
          else
            flash[:success] = "✅ Transfert de #{net}€ effectué ! Les fonds arrivent sur le compte bancaire de #{@project.user.name} sous 2-7 jours. Projet marqué comme Payé."
          end
        else
          error_msg = settlement.errors.any? ? settlement.errors.join(', ') : "Une erreur inconnue s'est produite"
          flash[:alert] = "Erreur transfert: #{error_msg}"
        end
      rescue => e
        flash[:alert] = "Erreur technique: #{e.message}"
        Rails.logger.error "Stripe Transfer Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Rembourse les contributeurs sélectionnés (ou tous si aucun ID spécifié)
    # Utilisé en cas de problème avec le porteur ou annulation
    def process_stripe_refund
      @project = Project.find_by_permalink params[:id]
      
      unless @project.use_stripe?
        flash[:alert] = "Stripe n'est pas activé pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      # Récupérer les IDs des contributions sélectionnées (si spécifiés)
      contribution_ids = params[:contribution_ids].present? ? params[:contribution_ids].split(',').map(&:to_i) : nil
      
      # Filtrer les contributions remboursables
      contributions = @project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                              .where(stripe_refunded: [false, nil])
                              .where(stripe_transferred: [false, nil])
      
      # Si des IDs sont spécifiés, filtrer uniquement ces contributions
      if contribution_ids.present?
        contributions = contributions.where(id: contribution_ids)
      end
      
      if contributions.empty?
        flash[:alert] = "Aucune contribution sélectionnée ou toutes déjà traitées."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        settlement = Neighborly::Stripe::CampaignSettlement.new(@project)
        
        # Passer les IDs des contributions à rembourser
        if settlement.process_refunds!(contribution_ids)
          # Afficher avertissement si certains remboursements ont échoué
          if settlement.errors.any?
            flash[:success] = "✅ Remboursements effectués avec avertissements: #{settlement.errors.join(', ')}"
          else
            flash[:success] = "✅ #{contributions.count} contribution(s) remboursée(s)! Les contributeurs recevront leur argent (moins frais) sous 5-10 jours."
          end
        else
          error_msg = settlement.errors.any? ? settlement.errors.join(', ') : "Une erreur inconnue s'est produite"
          flash[:alert] = "Erreur: #{error_msg}"
        end
      rescue => e
        flash[:alert] = "Erreur technique: #{e.message}"
        Rails.logger.error "Stripe Refund Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end

    protected
    def collection
      @projects = apply_scopes(end_of_association_chain).order('projects.created_at desc').without_state('deleted').page(params[:page])
    end

    def create_user
      password = Devise.friendly_token
      user = User.new(user_params[:user])
      user.email = "#{Devise.friendly_token}@populate.user"
      user.password = password
      user.password_confirmation = password
      user.profile_type = user_params[:user][:profile_type]
      user
    end

    def build_contribution(user)
      contribution = resource.contributions.new(contribution_params[:contribution])
      contribution.payment_method = 'PrePopulate'
      contribution.state = 'confirmed'
      contribution.user = user
      contribution
    end

    def user_params
      params.permit({ user: User.attribute_names.map(&:to_sym) })
    end

    def contribution_params
      params.permit({ contribution: Contribution.attribute_names.map(&:to_sym) })
    end

    def permitted_params
      params.permit({ project: Project.attribute_names.map(&:to_sym) })
    end
  end
end
