module Neighborly
  module Stripe
    # Service de règlement de fin de campagne crowdfunding
    # - Transfert: envoie les fonds collectés au porteur (peu importe si objectif atteint)
    # - Remboursement: rembourse les contributeurs (problèmes avec porteur, annulation)
    class CampaignSettlement
      attr_reader :project, :errors
      
      def initialize(project)
        @project = project
        @errors = []
      end
      
      # Traite le transfert au porteur (appelé quand on veut payer le porteur)
      # On transfère TOUJOURS ce qu'on a collecté, même si objectif non atteint
      # @return [Boolean] true si le traitement a réussi
      def process!
        return false unless valid_for_transfer?
        transfer_to_owner!
      end
      
      # Rembourse tous les contributeurs (appelé en cas de problème avec le porteur)
      # Peut être fait À TOUT MOMENT si des contributions existent
      # @return [Boolean] true si le traitement a réussi
      def process_refunds!
        return false unless valid_for_refund?
        refund_all_contributions!
      end
      
      # Transfère les fonds au porteur de projet
      # On transfère ce qu'on a collecté, peu importe si objectif atteint ou non
      # IMPORTANT: Utilise source_transaction pour lier au charge et éviter erreurs "insufficient funds"
      def transfer_to_owner!
        return false unless project.stripe_account_id.present?
        
        contributions = stripe_contributions.where(state: 'confirmed')
                                           .where(stripe_refunded: [false, nil])
                                           .where(stripe_transferred: [false, nil])
        return add_error("Aucune contribution à transférer") if contributions.empty?
        
        # Calculer les totaux pour le log
        total_collected_gross = contributions.sum(:value)
        total_stripe_fees = calculate_total_stripe_fees(contributions)
        total_net_amount = total_collected_gross - total_stripe_fees
        platform_fee = calculate_platform_fee(total_net_amount)
        total_to_transfer = total_net_amount - platform_fee
        
        Rails.logger.info "CampaignSettlement: Projet #{project.name}"
        Rails.logger.info "  - Brut collecté: #{total_collected_gross}€"
        Rails.logger.info "  - Frais Stripe: #{total_stripe_fees}€"
        Rails.logger.info "  - Net après Stripe: #{total_net_amount}€"
        Rails.logger.info "  - Commission Fiatope (5% du net): #{platform_fee}€"
        Rails.logger.info "  - Total à transférer: #{total_to_transfer}€"
        Rails.logger.info "  - Nombre de contributions: #{contributions.count}"
        
        # Transférer chaque contribution individuellement avec source_transaction
        # Cela évite les erreurs "insufficient funds" car Stripe lie le transfert au charge
        success_count = 0
        failed_contributions = []
        transfer_ids = []
        
        contributions.each do |contribution|
          result = transfer_single_contribution(contribution)
          if result[:success]
            success_count += 1
            transfer_ids << result[:transfer_id]
          else
            failed_contributions << { id: contribution.id, error: result[:error] }
          end
        end
        
        # Marquer le projet comme réglé si au moins un transfert a réussi
        if success_count > 0
          project.update(
            stripe_transfer_id: transfer_ids.first, # Premier transfert comme référence
            stripe_settled_at: Time.current,
            stripe_settlement_type: 'transferred'
          )
          
          Rails.logger.info "CampaignSettlement: #{success_count}/#{contributions.count} transferts réussis"
          
          # Notifier le porteur
          notify_owner_transfer_complete(nil, total_to_transfer)
        end
        
        if failed_contributions.any?
          @errors << "#{failed_contributions.count} contribution(s) non transférée(s): #{failed_contributions.map { |f| "#{f[:id]}: #{f[:error]}" }.join('; ')}"
          Rails.logger.error "CampaignSettlement: Erreurs - #{failed_contributions.inspect}"
        end
        
        success_count == contributions.count
      end
      
      # Transfère une seule contribution en utilisant source_transaction
      # Cela garantit que le transfert est lié au paiement original
      def transfer_single_contribution(contribution)
        # Récupérer le charge_id (nécessaire pour source_transaction)
        charge_id = contribution.stripe_charge_id
        
        # Si pas de charge_id stocké, le récupérer depuis le PaymentIntent
        if charge_id.blank? && contribution.payment_id.present?
          begin
            payment_intent = ::Stripe::PaymentIntent.retrieve(contribution.payment_id)
            charge_id = payment_intent.latest_charge
            # Stocker pour la prochaine fois
            contribution.update_column(:stripe_charge_id, charge_id) if charge_id.present?
          rescue ::Stripe::StripeError => e
            Rails.logger.warn "Impossible de récupérer charge_id pour contribution #{contribution.id}: #{e.message}"
          end
        end
        
        # Calculer le montant net pour cette contribution
        stripe_fee = calculate_stripe_fee_for_contribution(contribution)
        net_amount = contribution.value - stripe_fee
        platform_fee = (net_amount * 0.05).round(2) # 5% commission Fiatope
        amount_to_transfer = ((net_amount - platform_fee) * 100).to_i # en centimes
        
        return { success: false, error: "Montant trop faible" } if amount_to_transfer <= 0
        
        begin
          transfer_params = {
            amount: amount_to_transfer,
            currency: project.currency&.downcase || 'eur',
            destination: project.stripe_account_id,
            transfer_group: "project_#{project.id}",
            metadata: {
              contribution_id: contribution.id,
              project_id: project.id,
              gross_amount: contribution.value,
              stripe_fee: stripe_fee,
              platform_fee: platform_fee,
              net_to_owner: amount_to_transfer / 100.0
            }
          }
          
          # IMPORTANT: Utiliser source_transaction si on a le charge_id
          # Cela évite les erreurs "insufficient funds" et lie le transfert au paiement
          transfer_params[:source_transaction] = charge_id if charge_id.present?
          
          transfer = ::Stripe::Transfer.create(transfer_params)
          
          # Marquer la contribution comme transférée
          contribution.update(
            stripe_transferred: true,
            stripe_transfer_id: transfer.id
          )
          
          Rails.logger.info "CampaignSettlement: Contribution #{contribution.id} transférée (#{amount_to_transfer/100.0}€) - Transfer #{transfer.id}"
          
          { success: true, transfer_id: transfer.id }
        rescue ::Stripe::StripeError => e
          Rails.logger.error "CampaignSettlement: Erreur transfert contribution #{contribution.id} - #{e.message}"
          { success: false, error: e.message }
        end
      end
      
      # Calcule les frais Stripe pour une contribution spécifique
      def calculate_stripe_fee_for_contribution(contribution)
        if contribution.stripe_charge_id.present?
          begin
            charge = ::Stripe::Charge.retrieve(contribution.stripe_charge_id)
            balance_txn = ::Stripe::BalanceTransaction.retrieve(charge.balance_transaction)
            return (balance_txn.fee / 100.0)
          rescue ::Stripe::StripeError => e
            Rails.logger.warn "Impossible de récupérer frais Stripe pour contribution #{contribution.id}: #{e.message}"
          end
        end
        # Estimation si frais réels indisponibles
        estimate_stripe_fee(contribution.value)
      end
      
      # Rembourse toutes les contributions (problème avec porteur, annulation)
      # Peut être appelé À TOUT MOMENT
      def refund_all_contributions!
        contributions = stripe_contributions.where(state: 'confirmed').where(stripe_refunded: [false, nil])
        return add_error("Aucune contribution à rembourser") if contributions.empty?
        
        Rails.logger.info "CampaignSettlement: Remboursement de #{contributions.count} contributions pour projet #{project.name}"
        
        success_count = 0
        failed_contributions = []
        
        contributions.each do |contribution|
          if refund_contribution(contribution)
            success_count += 1
          else
            failed_contributions << contribution.id
          end
        end
        
        # Marquer le projet comme remboursé
        project.update(
          stripe_settled_at: Time.current,
          stripe_settlement_type: 'refunded'
        )
        
        Rails.logger.info "CampaignSettlement: #{success_count}/#{contributions.count} contributions remboursées"
        
        if failed_contributions.any?
          @errors << "#{failed_contributions.count} contributions non remboursées: #{failed_contributions.join(', ')}"
        end
        
        success_count == contributions.count
      end
      
      # Rembourse une contribution spécifique
      def refund_contribution(contribution)
        return false unless contribution.payment_id.present?
        
        begin
          # Récupérer le PaymentIntent pour obtenir le charge_id
          payment_intent = ::Stripe::PaymentIntent.retrieve(contribution.payment_id)
          charge_id = payment_intent.latest_charge
          
          return false unless charge_id.present?
          
          # Créer le remboursement
          refund = ::Stripe::Refund.create({
            charge: charge_id,
            metadata: {
              contribution_id: contribution.id,
              project_id: project.id,
              reason: 'campaign_failed'
            }
          })
          
          # Mettre à jour la contribution
          contribution.update(
            stripe_refunded: true,
            stripe_refund_id: refund.id
          )
          
          # Changer l'état de la contribution
          contribution.refund! if contribution.respond_to?(:refund!)
          
          # Notifier le contributeur
          notify_contributor_refund(contribution)
          
          Rails.logger.info "CampaignSettlement: Contribution #{contribution.id} remboursée (refund #{refund.id})"
          true
        rescue ::Stripe::StripeError => e
          @errors << "Erreur remboursement contribution #{contribution.id}: #{e.message}"
          Rails.logger.error "CampaignSettlement: Erreur remboursement #{contribution.id} - #{e.message}"
          false
        end
      end
      
      private
      
      def add_error(message)
        @errors << message
        false
      end
      
      # Validation pour le transfert au porteur
      def valid_for_transfer?
        unless project.present?
          return add_error("Projet non trouvé")
        end
        
        unless project.use_stripe?
          return add_error("Stripe n'est pas activé pour ce projet")
        end
        
        # SYNCHRONISATION AUTOMATIQUE: Si le projet n'a pas de stripe_account_id 
        # mais que le porteur en a un, synchroniser maintenant
        if project.stripe_account_id.blank? && project.user.stripe_connect_account_id.present?
          Rails.logger.info "CampaignSettlement: Synchronisation automatique du stripe_account_id depuis le porteur"
          project.update_columns(stripe_account_id: project.user.stripe_connect_account_id)
          project.reload
        end
        
        unless project.stripe_account_id.present?
          return add_error("Pas de compte Stripe connecté pour ce projet. Le porteur doit d'abord configurer son compte Stripe.")
        end
        
        unless project.user.stripe_onboarding_complete?
          return add_error("Le porteur n'a pas complété son profil Stripe")
        end
        
        # Vérifier si déjà transféré (plusieurs façons de le détecter pour éviter les doubles transferts)
        if project.stripe_settlement_type == 'transferred'
          return add_error("Le projet a déjà été réglé (transfert effectué)")
        end
        
        if project.stripe_transfer_id.present?
          return add_error("Un transfert a déjà été effectué (ID: #{project.stripe_transfer_id})")
        end
        
        contributions = stripe_contributions.where(state: 'confirmed').where(stripe_refunded: [false, nil]).where(stripe_transferred: [false, nil])
        if contributions.empty?
          return add_error("Aucune contribution Stripe confirmée à transférer (toutes déjà traitées)")
        end
        
        true
      end
      
      # Validation pour le remboursement - peut être fait À TOUT MOMENT
      def valid_for_refund?
        unless project.present?
          return add_error("Projet non trouvé")
        end
        
        unless project.use_stripe?
          return add_error("Stripe n'est pas activé pour ce projet")
        end
        
        # Vérifier si déjà remboursé
        if project.stripe_settlement_type == 'refunded'
          return add_error("Les contributions ont déjà été remboursées")
        end
        
        # Vérifier si déjà transféré - on ne peut PAS rembourser après un transfert!
        # Les fonds ne sont plus sur notre compte plateforme
        if project.stripe_settlement_type == 'transferred' || project.stripe_transfer_id.present?
          return add_error("Impossible de rembourser: les fonds ont déjà été transférés au porteur")
        end
        
        # Vérifier s'il reste des contributions non remboursées ET non transférées
        contributions = stripe_contributions.where(state: 'confirmed').where(stripe_refunded: [false, nil]).where(stripe_transferred: [false, nil])
        if contributions.empty?
          return add_error("Aucune contribution à rembourser (toutes déjà traitées ou aucune contribution Stripe)")
        end
        
        true
      end
      
      def stripe_contributions
        project.contributions.where(payment_method: 'Stripe')
      end
      
      def calculate_platform_fee(net_amount)
        # Commission Fiatope: 5% du montant NET (après frais Stripe)
        fee_percentage = ENV.fetch('PLATFORM_FEE', '5.0').to_f / 100
        (net_amount * fee_percentage).round(2)
      end
      
      # Calcule les frais Stripe totaux pour toutes les contributions
      # Stripe prend environ 1.4% + 0.25€ pour les cartes européennes
      # ou 2.9% + 0.25€ pour les cartes non-européennes
      def calculate_total_stripe_fees(contributions)
        total_fees = 0.0
        
        contributions.each do |contribution|
          if contribution.stripe_charge_id.present?
            begin
              # Récupérer les frais réels depuis Stripe
              charge = ::Stripe::Charge.retrieve(contribution.stripe_charge_id)
              balance_txn = ::Stripe::BalanceTransaction.retrieve(charge.balance_transaction)
              total_fees += (balance_txn.fee / 100.0)
            rescue ::Stripe::StripeError => e
              # En cas d'erreur, estimer les frais (3.4% + 0.25€)
              Rails.logger.warn "Impossible de récupérer les frais Stripe pour contribution #{contribution.id}: #{e.message}"
              total_fees += estimate_stripe_fee(contribution.value)
            end
          else
            # Si pas de charge_id, estimer les frais
            total_fees += estimate_stripe_fee(contribution.value)
          end
        end
        
        total_fees.round(2)
      end
      
      # Estime les frais Stripe si on ne peut pas les récupérer
      # Formule: 1.4% + 0.25€ (cartes EU) ou 2.9% + 0.25€ (cartes non-EU)
      # On prend une moyenne de ~2.5% + 0.25€
      def estimate_stripe_fee(amount)
        (amount * 0.025 + 0.25).round(2)
      end
      
      def notify_owner_transfer_complete(transfer, amount)
        begin
          project.notify_owner(:stripe_transfer_complete, {
            transfer_id: transfer.id,
            amount: amount,
            currency: project.currency || 'EUR'
          })
        rescue => e
          Rails.logger.warn "CampaignSettlement: Erreur notification transfert - #{e.message}"
        end
      end
      
      def notify_contributor_refund(contribution)
        begin
          contribution.notify_owner(:stripe_refund_complete, {
            project: project,
            amount: contribution.value
          })
        rescue => e
          Rails.logger.warn "CampaignSettlement: Erreur notification remboursement - #{e.message}"
        end
      end
    end
  end
end
