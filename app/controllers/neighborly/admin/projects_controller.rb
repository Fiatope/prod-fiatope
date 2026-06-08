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
          flash[:alert] = "Projet: l’état payé est autorisé uniquement après confirmation bancaire."
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
        flash[:alert] = "Le porteur #{@project.user.name} n’a pas encore de compte de paiement."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        service = Neighborly::Stripe::SyncService.new(@project.user)
        
        if service.sync_all!
          results = service.results
          flash[:success] = "✅ Mise à jour effectuée. " \
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

    # Vérifie explicitement les informations de paiement du porteur.
    def sync_payout_profile_to_stripe
      @project = Project.find_by_permalink params[:id]
      user = @project.user

      missing_fields = user.payout_profile_missing_fields
      unless missing_fields.empty?
        Rails.logger.warn "[Admin] Payout profile incomplete for project #{@project.id} (#{@project.permalink}) user #{user.id}: #{missing_fields.join(', ')}"
        reopen_result = reopen_payout_profile_edit!(@project)
        notification_message = reopen_result[:notification_sent] ? ' Un email a ete envoye au porteur.' : ' Attention: email porteur non envoye, voir les logs.'
        reopened_message = reopen_result[:reopened_request] ? ' La demande a ete rouverte pour une nouvelle soumission.' : ''
        flash[:alert] = "Informations ou documents de paiement incomplets: #{missing_fields.join(', ')}. Le formulaire a ete reactive pendant 14 jours.#{reopened_message}#{notification_message}"
        return redirect_back(fallback_location: projects_path)
      end

      sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(
        user,
        request_ip: request.remote_ip,
        user_agent: request.user_agent,
        tos_accepted: true
      )

      if sync_result.success?
        Rails.logger.info "[Admin] Payout profile sync success for project #{@project.id} (#{@project.permalink}) user #{user.id}, account=#{user.reload.stripe_connect_account_id}, warnings=#{sync_result.warnings.join(' | ')}"
        warnings = sync_result.warnings.any? ? " À vérifier: #{payout_profile_admin_failure_message(sync_result.warnings)}" : ''
        flash[:success] = "Informations de paiement vérifiées.#{warnings}"
      else
        handle_payout_profile_sync_failure!(sync_result, @project, 'Vérification impossible')
      end
    rescue => e
      flash[:alert] = "Vérification impossible pour le moment. Consultez les logs si le problème persiste."
      Rails.logger.error "[Admin] Payout profile sync error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    ensure
      redirect_back(fallback_location: projects_path) unless performed?
    end
    
    # Active Stripe pour un projet et crée/réutilise le compte connecté du porteur
    def enable_stripe
      @project = Project.find_by_permalink params[:id]
      
      if @project.use_stripe?
        # Forcer la synchronisation même si Stripe est déjà activé
        if @project.user.stripe_connect_account_id.present?
          if stripe_project_account_locked?(@project)
            flash[:notice] = "Action non effectuée: un retrait est déjà en cours ou historisé pour ce projet."
          else
            @project.update_column(:stripe_account_id, @project.user.stripe_connect_account_id)
            flash[:notice] = "Compte de paiement vérifié."
          end
        else
          flash[:notice] = "Le paiement en ligne est déjà activé pour ce projet."
        end
      else
        begin
          # Activer les paiements sans creer de compte de retrait avant la soumission du profil local.
          @project.update_columns(use_stripe: true)

          if @project.user.stripe_connect_account_id.present? && !stripe_project_account_locked?(@project)
            @project.update_column(:stripe_account_id, @project.user.stripe_connect_account_id)
          end
          
          if @project.user.payout_profile_complete?
            flash[:success] = "Paiement en ligne activé. Le porteur peut demander le paiement depuis la plateforme."
          else
            flash[:success] = "Paiement en ligne activé. Le porteur doit compléter ses informations et documents de paiement."
          end
        rescue => e
          flash[:alert] = "Impossible d’activer le paiement en ligne: #{e.message.truncate(200)}"
        end
      end
      
      redirect_back(fallback_location: projects_path)
    end

    def stripe_project_account_locked?(project)
      if project.respond_to?(:stripe_account_locked_for_payout?)
        return project.stripe_account_locked_for_payout?
      end

      settlement_type = project.respond_to?(:stripe_settlement_type) ? project.stripe_settlement_type.to_s : ''
      payout_status = project.respond_to?(:stripe_payout_status) ? project.stripe_payout_status.to_s : ''
      payout_id = project.respond_to?(:stripe_payout_id) ? project.stripe_payout_id : nil

      settlement_type == 'transferred' ||
        payout_id.present? ||
        %w[pending in_transit paid failed canceled].include?(payout_status)
    end
    
    # Action desactivee: plus de generation de lien d'onboarding externe.
    def stripe_onboarding_link
      @project = Project.find_by_permalink params[:id]
      flash[:alert] = "Cette action est désactivée. Le porteur doit compléter ses informations et documents de paiement sur la plateforme."
      
      redirect_back(fallback_location: projects_path)
    end
    
    # Transfère les fonds au porteur (peu importe si objectif atteint ou non)
    # On transfère ce qu'on a collecté au porteur
    def process_stripe_transfer
      @project = Project.find_by_permalink params[:id]
      
      unless @project.use_stripe?
        flash[:alert] = "Le paiement en ligne n’est pas activé pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      unless @project.user.payout_profile_complete?
        flash[:alert] = "Le porteur n’a pas complété ses informations et documents de paiement."
        return redirect_back(fallback_location: projects_path)
      end

      sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(
        @project.user,
        request_ip: request.remote_ip,
        user_agent: request.user_agent,
        tos_accepted: true
      )
      unless sync_result.success?
        handle_payout_profile_sync_failure!(sync_result, @project, 'Vérification impossible avant paiement')
        return redirect_back(fallback_location: projects_path)
      end
      @project.reload
      
      payout_status = @project.stripe_payout_status.to_s
      remaining_contributions = @project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                                        .where(stripe_refunded: [false, nil], stripe_transferred: [false, nil])
      payout_blocks_retry = %w[pending in_transit manual_review].include?(payout_status) ||
                            (payout_status == 'paid' && remaining_contributions.empty?)
      if @project.stripe_settlement_type == 'transferred' && payout_blocks_retry
        flash[:notice] = if payout_status == 'paid'
                           "Le virement bancaire a déjà été confirmé."
                         elsif payout_status == 'manual_review'
                           "Une vérification manuelle est requise avant toute nouvelle opération."
                         else
                           "Un virement bancaire est déjà en cours. Le projet sera marqué payé après confirmation bancaire."
                         end
        return redirect_back(fallback_location: projects_path)
      end
      
      # Vérifier qu'il y a des contributions à transférer
      contributions = @project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                              .where(stripe_refunded: [false, nil])
      if contributions.empty?
        flash[:alert] = "Aucune contribution en ligne à transférer."
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
            flash[:notice] = "Paiement préparé avec avertissements: #{settlement.errors.join(', ').truncate(200)}. Le projet reste en demande jusqu’à confirmation bancaire."
          elsif settlement.payouts.any?
            flash[:success] = if was_already_transferred
                                "Virement bancaire créé ou repris. Le projet sera marqué payé après confirmation bancaire."
                              else
                                "Paiement de #{total} EUR préparé et virement bancaire créé. Le projet sera marqué payé après confirmation bancaire."
                              end
          elsif %w[pending in_transit].include?(payout_status)
            flash[:notice] = "Un virement bancaire est en cours. Le projet sera marqué payé après confirmation bancaire."
          else
            flash[:notice] = "Paiement préparé. Créez ou validez le virement bancaire; le projet sera marqué payé après confirmation bancaire."
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
        flash[:alert] = "Le paiement en ligne n’est pas activé pour ce projet."
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
        flash[:alert] = "Le paiement en ligne n’est pas activé pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      stripe_count = @project.stripe_contributions.where(state: 'confirmed').count
      if stripe_count.zero?
        flash[:notice] = "Aucune contribution en ligne à vérifier pour ce projet."
        return redirect_back(fallback_location: projects_path)
      end
      
      begin
        results = @project.verify_stripe_wallet
        totals = results[:totals]
        
        if totals[:match] && results[:errors].empty?
          flash[:success] = "✅ Solde vérifié: #{totals[:verified_count]} contribution(s), " \
            "total plateforme #{totals[:db_total]}€ = prestataire de paiement #{totals[:stripe_total]}€. Tout est cohérent."
        else
          parts = []
          parts << "✅ #{totals[:verified_count]} OK" if totals[:verified_count] > 0
          parts << "⚠️ #{totals[:mismatch_count]} écarts" if totals[:mismatch_count] > 0
          parts << "❌ #{totals[:error_count]} erreurs" if totals[:error_count] > 0
          parts << "Plateforme: #{totals[:db_total]}€ vs prestataire de paiement: #{totals[:stripe_total]}€"
          parts << "Diff: #{totals[:difference]}€" unless totals[:match]
          
          flash_key = totals[:mismatch_count] > 0 || totals[:error_count] > 0 ? :alert : :success
          flash[flash_key] = "Vérification wallet: #{parts.join(' | ')}"
        end
        
        # Stocker les détails pour le modal (limiter la taille pour le cookie)
        detail_parts = []
        results[:mismatches].each do |m|
          detail_parts << "Contribution ##{m[:contribution_id]}: plateforme=#{m[:db_amount]}€ prestataire=#{m[:stripe_amount]}€ (#{m[:difference] > 0 ? '+' : ''}#{m[:difference]}€)"
        end
        results[:errors].each do |e|
          detail_parts << "Contrib ##{e[:contribution_id]}: #{e[:error].to_s.truncate(80)}"
        end
        flash[:wallet_details] = detail_parts.join("\n") if detail_parts.any?
        
      rescue => e
        flash[:alert] = "Impossible de vérifier le solde: #{e.message.truncate(200)}"
        Rails.logger.error "Verify Wallet Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
      
      redirect_back(fallback_location: projects_path)
    end

    # Autorise le porteur à corriger ses informations et documents de paiement.
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

      notification_sent = notify_payout_profile_update_required(@project)
      notification_message = notification_sent ? ' Un email a été envoyé au porteur.' : ' Attention: email porteur non envoyé, voir les logs.'

      render json: {
        success: true,
        message: (reopened_request ? 'Autorisation enregistrée. La demande a été rouverte pour une nouvelle soumission.' : 'Le porteur peut corriger et renvoyer ses informations et documents pendant 14 jours.') + notification_message
      }
    rescue => e
      Rails.logger.error "unlock_payout_profile_edit failed: #{e.message}"
      render json: { success: false, error: "Impossible d’autoriser la correction: #{e.message}" }, status: :unprocessable_entity
    end

    # Données locales des informations de paiement du porteur.
    def payout_profile
      @project = Project.find_by_permalink params[:id]
      user = @project.user
      bank = user.bank_information
      required_types = user.payout_profile_required_kyc_types

      documents_by_type = user.kycs.where(proof_type: required_types).order(created_at: :desc).group_by(&:proof_type)

      render json: {
        profile_complete: user.payout_profile_complete?,
        missing_fields: user.payout_profile_missing_fields,
        stripe: payout_profile_stripe_status(user),
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

    def handle_payout_profile_sync_failure!(sync_result, project, prefix)
      errors = Array(sync_result.errors)
      Rails.logger.warn "[Admin] Payout profile sync failed for project #{project.id} (#{project.permalink}) user #{project.user_id}: #{errors.join(' | ')}"

      if payout_profile_owner_action_required?(errors)
        reopen_result = reopen_payout_profile_edit!(project)
        notification_message = reopen_result[:notification_sent] ? ' Un email a été envoyé au porteur.' : ' Attention: email porteur non envoyé, voir les logs.'
        reopened_message = reopen_result[:reopened_request] ? ' La demande a été rouverte pour une nouvelle soumission.' : ''
        flash[:alert] = "#{prefix}: #{payout_profile_admin_failure_message(errors)} Le formulaire a été réactivé pendant 14 jours.#{reopened_message}#{notification_message}"
      else
        flash[:alert] = "#{prefix}: #{payout_profile_admin_failure_message(errors)}"
      end
    end

    def payout_profile_owner_action_required?(errors)
      details = Array(errors).join(' ')
      return false if details.match?(/responsibilities of collecting requirements|platform-profile|platform profile|collecting requirements/i)

      details.match?(/Profil de retrait incomplet|conditions de paiement|accepter les conditions|valid phone|phone|not currently supported|not supported|postal|zip|iban|bank account|account_number|routing|date of birth|dob|birthday|address|city|country|line1|document|file|upload/i)
    end

    def payout_profile_admin_failure_message(errors)
      details = Array(errors).join(' ')

      return 'le profil Stripe Connect de la plateforme doit être finalisé dans le Dashboard Stripe. Le porteur n’a rien à corriger.' if details.match?(/responsibilities of collecting requirements|platform-profile|platform profile|collecting requirements/i)
      return 'le porteur doit cocher l’attestation et renvoyer ses informations depuis la plateforme.' if details.match?(/conditions de paiement|accepter les conditions/i)
      return 'le numéro de téléphone doit être corrigé au format international.' if details.match?(/valid phone|phone/i)
      return 'le pays ou le compte bancaire renseigné n’est pas pris en charge pour ce paiement.' if details.match?(/not currently supported|not supported/i)
      return 'le code postal doit être corrigé.' if details.match?(/postal|zip/i)
      return 'les informations bancaires doivent être corrigées.' if details.match?(/iban|bank account|account_number|routing/i)
      return 'la date de naissance doit être corrigée.' if details.match?(/date of birth|dob|birthday/i)
      return 'l’adresse du titulaire doit être corrigée.' if details.match?(/address|city|country|line1/i)
      return 'un document doit être corrigé ou renvoyé.' if details.match?(/document|file|upload/i)

      'le porteur doit vérifier et renvoyer ses informations et documents de paiement.'
    end

    def reopen_payout_profile_edit!(project)
      reopened_request = false

      if project.state == 'request_funds'
        project.update_column(:state, 'waiting_funds')
        reopened_request = true
      end

      Rails.cache.write(
        payout_profile_edit_unlock_cache_key(project.user),
        { unlocked_at: Time.current.to_i, admin_id: current_user.try(:id) },
        expires_in: 14.days
      )

      {
        reopened_request: reopened_request,
        notification_sent: notify_payout_profile_update_required(project)
      }
    end

    def payout_profile_edit_unlock_cache_key(user)
      "payout_profile_edit_unlock:user:#{user.id}"
    end

    def notify_payout_profile_update_required(project)
      Notification.notify_once(
        :payout_profile_update_required,
        project.user,
        nil,
        project: project
      )
      true
    rescue => e
      Rails.logger.error "payout_profile_update_required notification failed: #{e.message}"
      false
    end

    def payout_profile_stripe_status(user)
      return { account_id: nil, error: 'Aucun compte Stripe Connect local.' } if user.stripe_connect_account_id.blank?

      account = ::Stripe::Account.retrieve(user.stripe_connect_account_id)
      requirements = account.requirements
      future_requirements = account.future_requirements
      {
        account_id: account.id,
        payouts_enabled: account.payouts_enabled,
        charges_enabled: account.charges_enabled,
        transfers: stripe_object_value(account.capabilities, :transfers),
        currently_due: Array(stripe_object_value(requirements, :currently_due)),
        past_due: Array(stripe_object_value(requirements, :past_due)),
        eventually_due: Array(stripe_object_value(requirements, :eventually_due)),
        pending_verification: Array(stripe_object_value(requirements, :pending_verification)),
        disabled_reason: stripe_object_value(requirements, :disabled_reason),
        future_currently_due: Array(stripe_object_value(future_requirements, :currently_due)),
        future_past_due: Array(stripe_object_value(future_requirements, :past_due)),
        errors: Array(stripe_object_value(requirements, :errors)).map { |error| payout_profile_requirement_error(error) }
      }
    rescue ::Stripe::StripeError => e
      { account_id: user.stripe_connect_account_id, error: e.message }
    end

    def payout_profile_requirement_error(error)
      {
        requirement: stripe_object_value(error, :requirement),
        code: stripe_object_value(error, :code),
        reason: stripe_object_value(error, :reason)
      }
    end

    def stripe_object_value(object, key)
      return nil unless object
      return object[key] if object.respond_to?(:[]) && object[key].present?
      return object[key.to_s] if object.respond_to?(:[]) && object[key.to_s].present?
      return object.public_send(key) if object.respond_to?(key)

      nil
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
