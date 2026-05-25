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
        if name == :push_to_paid && @project.respond_to?(:use_stripe?) && @project.use_stripe? && @project.stripe_payout_status.to_s != 'paid'
          flash[:alert] = "Projet Stripe: l'etat paye est autorise uniquement apres confirmation bancaire Stripe payout.paid."
          return redirect_back(fallback_location: root_path)
        end

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
          
          if @project.user.payout_profile_complete?
            flash[:success] = "Stripe active! Le porteur peut soumettre sa demande de retrait depuis la plateforme."
          else
            flash[:success] = "Stripe active! Le porteur doit completer son profil de retrait local (identite, banque, justificatifs)."
          end
        rescue => e
          flash[:alert] = "Erreur lors de l'activation de Stripe: #{e.message}"
        end
      end
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Action desactivee: plus de generation de lien d'onboarding externe.
    def stripe_onboarding_link
      @project = Project.find_by_permalink params[:id]
      flash[:alert] = "Cette action est desactivee. Le porteur doit completer son profil de retrait directement sur la plateforme."
      
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
      
      unless @project.user.payout_profile_complete?
        flash[:alert] = "Le porteur n'a pas complete son profil de retrait local (identite, banque, justificatifs)."
        return redirect_back(fallback_location: projects_path)
      end

      sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(@project.user)
      unless sync_result.success?
        flash[:alert] = "Synchronisation Stripe impossible avant transfert: #{sync_result.errors.join(', ')}"
        return redirect_back(fallback_location: projects_path)
      end
      
      payout_status = @project.stripe_payout_status.to_s
      if @project.stripe_settlement_type == 'transferred' && %w[paid pending in_transit].include?(payout_status)
        flash[:notice] = if payout_status == 'paid'
                           "Le virement bancaire Stripe a deja ete confirme."
                         else
                           "Un virement bancaire Stripe est deja en cours. Le projet passera en paye apres confirmation bancaire Stripe."
                         end
        return redirect_back(fallback_location: projects_path)
      end
      
      # Vérifier qu'il y a des contributions à transférer
      contributions = @project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                              .where(stripe_refunded: [false, nil])
      if contributions.empty?
        flash[:alert] = "Aucune contribution Stripe à transférer."
        return redirect_back(fallback_location: projects_path)
      end
      was_already_transferred = @project.stripe_settlement_type == 'transferred'
      
      begin
        settlement = Neighborly::Stripe::CampaignSettlement.new(@project)
        
        if settlement.process!
          @project.reload
          total = contributions.sum(:value)
          payout_status = @project.stripe_payout_status.to_s
          if settlement.errors.any?
            flash[:notice] = "Transfert Stripe traite avec avertissements: #{settlement.errors.join(', ').truncate(200)}. Le projet reste en demande jusqu'a confirmation bancaire Stripe."
          elsif settlement.payouts.any?
            flash[:success] = if was_already_transferred
                                "Virement bancaire Stripe cree ou repris. Le projet passera en paye uniquement apres le webhook payout.paid."
                              else
                                "Transfert interne de #{total} EUR traite et virement bancaire Stripe cree. Le projet passera en paye uniquement apres le webhook payout.paid."
                              end
          elsif %w[pending in_transit].include?(payout_status)
            flash[:notice] = "Un virement bancaire Stripe est en cours. Le projet passera en paye uniquement apres confirmation bancaire Stripe."
          else
            flash[:notice] = "Transfert interne traite. Creez ou validez le virement bancaire Stripe; le projet passera en paye uniquement apres payout.paid."
          end
        else
          error_msg = settlement.errors.any? ? settlement.errors.join(', ').truncate(200) : "Une erreur inconnue s'est produite"
          flash[:alert] = "Erreur: #{error_msg}"
        end
      rescue => e
        flash[:alert] = "Erreur technique: #{e.message.truncate(200)}"
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
            flash[:success] = "✅ Remboursements effectués avec avertissements: #{settlement.errors.join(', ').truncate(200)}"
          else
            flash[:success] = "✅ #{contributions.count} contribution(s) remboursée(s)! Les contributeurs recevront leur argent (moins frais) sous 5-10 jours."
          end
        else
          error_msg = settlement.errors.any? ? settlement.errors.join(', ').truncate(200) : "Une erreur inconnue s'est produite"
          flash[:alert] = "Erreur: #{error_msg}"
        end
      rescue => e
        flash[:alert] = "Erreur technique: #{e.message.truncate(200)}"
        Rails.logger.error "Stripe Refund Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end

    # Vérification wallet: réconciliation DB vs Stripe API charge par charge
    def verify_stripe_wallet
      @project = Project.find_by_permalink params[:id]
      
      unless @project.use_stripe?
        flash[:alert] = "Stripe n'est pas activé pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      stripe_count = @project.stripe_contributions.where(state: 'confirmed').count
      if stripe_count.zero?
        flash[:notice] = "Aucune contribution Stripe à vérifier pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        results = @project.verify_stripe_wallet
        totals = results[:totals]
        
        if totals[:match] && results[:errors].empty?
          flash[:success] = "✅ Wallet vérifié: #{totals[:verified_count]} contribution(s), " \
            "total DB #{totals[:db_total]}€ = Stripe #{totals[:stripe_total]}€. Tout est cohérent."
        else
          parts = []
          parts << "✅ #{totals[:verified_count]} OK" if totals[:verified_count] > 0
          parts << "⚠️ #{totals[:mismatch_count]} écarts" if totals[:mismatch_count] > 0
          parts << "❌ #{totals[:error_count]} erreurs" if totals[:error_count] > 0
          parts << "DB: #{totals[:db_total]}€ vs Stripe: #{totals[:stripe_total]}€"
          parts << "Diff: #{totals[:difference]}€" unless totals[:match]
          
          flash_key = totals[:mismatch_count] > 0 || totals[:error_count] > 0 ? :alert : :success
          flash[flash_key] = "Vérification wallet: #{parts.join(' | ')}"
        end
        
        # Stocker les détails pour le modal (limiter la taille pour le cookie)
        detail_parts = []
        results[:mismatches].each do |m|
          detail_parts << "Contrib ##{m[:contribution_id]}: DB=#{m[:db_amount]}€ Stripe=#{m[:stripe_amount]}€ (#{m[:difference] > 0 ? '+' : ''}#{m[:difference]}€)"
        end
        results[:errors].each do |e|
          detail_parts << "Contrib ##{e[:contribution_id]}: #{e[:error].to_s.truncate(80)}"
        end
        flash[:wallet_details] = detail_parts.join("\n") if detail_parts.any?
        
      rescue => e
        flash[:alert] = "Erreur technique: #{e.message.truncate(200)}"
        Rails.logger.error "Verify Wallet Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end

    # Donnees locales du profil de retrait du porteur (identite, banque, KYC).
    def unlock_payout_profile_edit
      @project = Project.find_by_permalink params[:id]
      user = @project.user
      reopened_request = false

      if @project.state == 'request_funds'
        @project.update_column(:state, 'waiting_funds')
        reopened_request = true
      end

      Rails.cache.write(
        payout_profile_edit_unlock_cache_key(user),
        { unlocked_at: Time.current.to_i, admin_id: current_user.try(:id) },
        expires_in: 14.days
      )

      render json: {
        success: true,
        message: reopened_request ? 'Autorisation enregistree. La demande a ete reouverte pour une nouvelle soumission.' : 'Le porteur peut modifier et soumettre a nouveau son profil de retrait pendant 14 jours.'
      }
    rescue => e
      Rails.logger.error "unlock_payout_profile_edit failed: #{e.message}"
      render json: { success: false, error: "Impossible d autoriser la reedition: #{e.message}" }, status: :unprocessable_entity
    end

    # Donnees locales du profil de retrait du porteur (identite, banque, KYC).
    def payout_profile
      @project = Project.find_by_permalink params[:id]
      user = @project.user
      bank = user.bank_information
      required_types = user.payout_profile_required_kyc_types

      documents_by_type = user.kycs.where(proof_type: required_types).order(created_at: :desc).group_by(&:proof_type)

      render json: {
        profile_complete: user.payout_profile_complete?,
        missing_fields: user.payout_profile_missing_fields,
        owner: {
          id: user.id,
          name: user.name,
          email: user.email,
          profile_type: user.profile_type,
          organization_name: user.organization&.name,
          birthday: user.birthday,
          nationality: user.nationality,
          residence_country: user.residence_country,
          mobile_phone: user.mobile_phone,
          stripe_connect_account_id: user.stripe_connect_account_id,
          stripe_onboarding_complete: user.stripe_onboarding_complete
        },
        bank: {
          owner_address: bank&.owner_address,
          owner_city: bank&.owner_city,
          owner_region: bank&.owner_region,
          owner_postal_code: bank&.owner_postal_code,
          other_country: bank&.other_country,
          bank_reference_type: bank&.payout_bank_reference_type&.upcase,
          bank_reference_value: bank&.payout_bank_reference_value,
          iban: bank&.iban,
          bic: bank&.bic
        },
        kyc_documents: required_types.map { |proof_type|
          documents = Array(documents_by_type[proof_type]).map do |document|
            url = document.uploaded_image&.url
            next if url.blank?

            identifier = document.uploaded_image_identifier.to_s
            filename = identifier.presence || File.basename(url.to_s.split('?').first)
            extension = File.extname(filename.to_s).delete('.').downcase
            {
              id: document.id,
              uploaded_at: document.created_at,
              url: url,
              filename: filename,
              extension: extension,
              image: %w[jpg jpeg png gif webp].include?(extension),
              pdf: extension == 'pdf'
            }
          end.compact

          {
            proof_type: proof_type,
            label: user.payout_kyc_label(proof_type),
            uploaded: documents.any?,
            uploaded_at: documents.first&.dig(:uploaded_at),
            url: documents.first&.dig(:url),
            documents: documents
          }
        }
      }
    end

    protected

    def payout_profile_edit_unlock_cache_key(user)
      "payout_profile_edit_unlock:user:#{user.id}"
    end

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
