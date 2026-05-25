module Neighborly
  module Stripe
    # Service de règlement de fin de campagne crowdfunding
    # - Transfert: envoie les fonds collectés au porteur (peu importe si objectif atteint)
    # - Remboursement: rembourse les contributeurs (problèmes avec porteur, annulation)
    class CampaignSettlement
      attr_reader :project, :errors, :payouts
      
      def initialize(project)
        @project = project
        @errors = []
        @payouts = []
      end
      
      # Traite le transfert au porteur (appelé quand on veut payer le porteur)
      # On transfère TOUJOURS ce qu'on a collecté, même si objectif non atteint
      # @return [Boolean] true si le traitement a réussi
      def process!
        return false unless valid_for_transfer?
        if transferable_contributions.any?
          transfer_to_owner!
        else
          create_bank_payout_for_transferred_funds!
        end
      end
      
      # Rembourse les contributeurs sélectionnés (ou tous si aucun ID spécifié)
      # Peut être fait À TOUT MOMENT si des contributions existent
      # @param contribution_ids [Array<Integer>, nil] IDs des contributions à rembourser (nil = toutes)
      # @return [Boolean] true si le traitement a réussi
      def process_refunds!(contribution_ids = nil)
        return false unless valid_for_refund?(contribution_ids)
        refund_contributions!(contribution_ids)
      end
      
      # Transfère les fonds au porteur de projet
      # On transfère ce qu'on a collecté, peu importe si objectif atteint ou non
      # IMPORTANT: Utilise source_transaction pour lier au charge et éviter erreurs "insufficient funds"
      def transfer_to_owner!
        return false unless project.stripe_account_id.present?
        
        contributions = transferable_contributions
        return add_error("Aucune contribution à transférer") if contributions.empty?
        
        # Calcul des totaux
        # PLATFORM_FEE est le % TOTAL annoncé au porteur (il inclut les frais Stripe)
        # Porteur reçoit: montant_brut * (1 - PLATFORM_FEE%). Ex: 100€ * (1-4%) = 96€
        # La plateforme garde PLATFORM_FEE% dont une partie couvre les frais Stripe réels
        fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        total_collected_gross  = contributions.sum(:value)
        total_platform_fee     = (total_collected_gross * fee_pct).round(2)
        total_to_transfer      = total_collected_gross - total_platform_fee
        total_stripe_fees      = calculate_total_stripe_fees(contributions)  # Pour info seulement
        platform_net_revenue   = total_platform_fee - total_stripe_fees       # Ce que la plateforme garde vraiment
        
        Rails.logger.info "CampaignSettlement: Projet #{project.name}"
        Rails.logger.info "  - Brut collecté: #{total_collected_gross}€"
        Rails.logger.info "  - Commission totale annoncée (#{(fee_pct * 100)}%): #{total_platform_fee}€"
        Rails.logger.info "  - dont frais Stripe estimés: #{total_stripe_fees}€"
        Rails.logger.info "  - dont revenu net plateforme: #{platform_net_revenue}€"
        Rails.logger.info "  - Total à transférer au porteur: #{total_to_transfer}€"
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
        
        if success_count > 0
          project.update(
            stripe_transfer_id: transfer_ids.first,
            stripe_transfer_created_at: Time.current,
            stripe_settled_at: nil,
            stripe_settlement_type: 'transferred',
            stripe_payout_status: project.stripe_payout_status.presence || 'requires_payout',
            stripe_payout_failure_code: nil,
            stripe_payout_failure_message: nil,
            stripe_payout_failed_at: nil
          )
          
          Rails.logger.info "CampaignSettlement: #{success_count}/#{contributions.count} transferts réussis"

          notify_owner_transfer_complete(nil, total_to_transfer) if create_bank_payout_for_transferred_funds!
        else
          # Aucun transfert réussi
          @errors << "Aucun transfert n'a pu être effectué" if @errors.empty?
        end
        
        if failed_contributions.any?
          @errors << "#{failed_contributions.count} contribution(s) non transférée(s): #{failed_contributions.map { |f| "#{f[:id]}: #{f[:error]}" }.join('; ')}"
          Rails.logger.error "CampaignSettlement: Erreurs - #{failed_contributions.inspect}"
        end
        
        # Succès si au moins un transfert interne a réussi
        success_count > 0
      end
      
      # Transfère une seule contribution en utilisant source_transaction
      # Cela garantit que le transfert est lié au paiement original
      def transfer_single_contribution(contribution)
        # Récupérer le charge_id (nécessaire pour source_transaction)
        charge_id = contribution.stripe_charge_id
        charge_object = nil
        
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
        
        # Récupérer la devise RÉELLE du charge depuis Stripe
        # IMPORTANT: Quand on utilise source_transaction, la devise du transfert
        # DOIT correspondre à la devise du balance_transaction du charge.
        # Si le compte plateforme règle en RON, le balance_transaction est en RON
        # même si le charge a été créé en EUR.
        transfer_currency = project.currency&.downcase || 'eur'
        balance_txn = nil
        if charge_id.present?
          begin
            charge_object = ::Stripe::Charge.retrieve(charge_id)
            if charge_object.balance_transaction.present?
              balance_txn = ::Stripe::BalanceTransaction.retrieve(charge_object.balance_transaction)
              transfer_currency = balance_txn.currency
              Rails.logger.info "  Contribution #{contribution.id}: devise balance_transaction = #{transfer_currency} (charge devise = #{charge_object.currency})"
            end
          rescue ::Stripe::StripeError => e
            Rails.logger.warn "  Contribution #{contribution.id}: impossible de récupérer la devise du charge, utilisation de #{transfer_currency}: #{e.message}"
          end
        end
        
        # PLATFORM_FEE = pourcentage TOTAL annoncé au porteur (inclut frais Stripe)
        # Porteur reçoit: montant * (1 - PLATFORM_FEE/100)
        fee_percentage = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        
        # Calcul du montant à transférer selon la devise
        # CRITIQUE: Si la balance_transaction est dans une devise différente (ex: RON),
        # le montant du transfert DOIT être en centimes de CETTE devise, pas en EUR.
        if balance_txn && balance_txn.currency != (charge_object&.currency || project.currency&.downcase || 'eur')
          # ===== CAS MULTI-DEVISE (ex: charge EUR → balance RON) =====
          bt_gross_cents = balance_txn.amount       # montant brut en centimes devise plateforme (RON)
          bt_fee_cents   = balance_txn.fee          # frais Stripe en centimes devise plateforme
          bt_net_cents   = balance_txn.net           # net après frais Stripe
          exchange_rate  = balance_txn.exchange_rate # taux EUR → RON
          
          # Commission plateforme en centimes devise plateforme
          platform_fee_cents = (bt_gross_cents * fee_percentage).round
          amount_to_transfer = bt_gross_cents - platform_fee_cents
          
          # Sécurité: ne pas dépasser le net disponible (brut - frais Stripe)
          if amount_to_transfer > bt_net_cents
            Rails.logger.warn "  Contribution #{contribution.id}: montant transfert (#{amount_to_transfer}) > net dispo (#{bt_net_cents}), cap à net"
            amount_to_transfer = bt_net_cents
          end
          
          # Logs en EUR pour lisibilité
          platform_fee_eur = exchange_rate && exchange_rate > 0 ? (platform_fee_cents / 100.0 / exchange_rate).round(2) : (contribution.value * fee_percentage).round(2)
          amount_to_owner_eur = exchange_rate && exchange_rate > 0 ? (amount_to_transfer / 100.0 / exchange_rate).round(2) : (contribution.value - platform_fee_eur).round(2)
          stripe_fee_eur = exchange_rate && exchange_rate > 0 ? (bt_fee_cents / 100.0 / exchange_rate).round(2) : estimate_stripe_fee(contribution.value)
          platform_net_eur = platform_fee_eur - stripe_fee_eur
          
          Rails.logger.info "  Contribution #{contribution.id} [MULTI-DEVISE]: charge=#{charge_object&.currency}, balance=#{transfer_currency}, taux=#{exchange_rate}"
          Rails.logger.info "    BT: brut=#{bt_gross_cents}c, frais=#{bt_fee_cents}c, net=#{bt_net_cents}c (#{transfer_currency})"
          Rails.logger.info "    Commission: #{platform_fee_cents}c #{transfer_currency} (~#{platform_fee_eur}€), transfert: #{amount_to_transfer}c #{transfer_currency} (~#{amount_to_owner_eur}€)"
          Rails.logger.info "    Equiv EUR: brut=#{contribution.value}€, commission=#{platform_fee_eur}€ (#{(fee_percentage*100)}%), stripe=#{stripe_fee_eur}€, net_plateforme=#{platform_net_eur}€, porteur=#{amount_to_owner_eur}€"
        else
          # ===== CAS MÊME DEVISE (ex: charge EUR → balance EUR) =====
          platform_fee      = (contribution.value * fee_percentage).round(2)
          amount_to_owner   = contribution.value - platform_fee
          amount_to_transfer = (amount_to_owner * 100).to_i # en centimes
          
          stripe_fee = balance_txn ? (balance_txn.fee / 100.0) : estimate_stripe_fee(contribution.value)
          platform_net_revenue = platform_fee - stripe_fee
          
          Rails.logger.info "  Contribution #{contribution.id}: brut=#{contribution.value}€, commission=#{platform_fee}€ (#{(fee_percentage*100)}%), stripe=#{stripe_fee}€, net_plateforme=#{platform_net_revenue}€, porteur=#{amount_to_owner}€, devise=#{transfer_currency}"
        end
        
        return { success: false, error: "Montant trop faible" } if amount_to_transfer <= 0
        
        begin
          transfer_params = {
            amount: amount_to_transfer,
            currency: transfer_currency,
            destination: project.stripe_account_id,
            transfer_group: "project_#{project.id}",
            description: "Virement campagne #{project.name} - contribution ##{contribution.id}",
            metadata: {
              contribution_id: contribution.id,
              project_id: project.id,
              gross_amount: contribution.value,
              platform_fee_pct: (fee_percentage * 100).to_s + '%',
              net_to_owner: amount_to_transfer / 100.0,
              transfer_currency: transfer_currency
            }
          }
          
          # IMPORTANT: Utiliser source_transaction si on a le charge_id
          # Cela évite les erreurs "insufficient funds" et lie le transfert au paiement
          transfer_params[:source_transaction] = charge_id if charge_id.present?
          
          transfer = ::Stripe::Transfer.create(transfer_params)
          
          # Marquer la contribution comme transférée
          contribution.update(
            stripe_transferred: true,
            stripe_transfer_id: transfer.id,
            stripe_transfer_amount_cents: amount_to_transfer,
            stripe_transfer_currency: transfer_currency
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
      
      # Rembourse les contributions sélectionnées (ou toutes si aucun ID spécifié)
      # @param contribution_ids [Array<Integer>, nil] IDs des contributions à rembourser (nil = toutes)
      def refund_contributions!(contribution_ids = nil)
        contributions = stripe_contributions.where(state: 'confirmed')
                                           .where(stripe_refunded: [false, nil])
                                           .where(stripe_transferred: [false, nil])
        
        # Filtrer par IDs si spécifiés
        contributions = contributions.where(id: contribution_ids) if contribution_ids.present?
        
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
        
        # Marquer le projet comme remboursé si au moins un remboursement a réussi
        if success_count > 0
          project.update(
            stripe_settled_at: Time.current,
            stripe_settlement_type: 'refunded'
          )
          Rails.logger.info "CampaignSettlement: #{success_count}/#{contributions.count} contributions remboursées"
        else
          @errors << "Aucun remboursement n'a pu être effectué" if @errors.empty?
        end
        
        if failed_contributions.any?
          @errors << "#{failed_contributions.count} contributions non remboursées: #{failed_contributions.join(', ')}"
        end
        
        # Succès si au moins un remboursement a réussi
        success_count > 0
      end
      
      # Rembourse une contribution spécifique
      # IMPORTANT: On rembourse le montant NET (après déduction frais Stripe + commission plateforme)
      # Le contributeur ne reçoit PAS 100% car les frais Stripe sont non-remboursables
      # et la plateforme retient sa commission
      def refund_contribution(contribution)
        return false unless contribution.payment_id.present?
        
        begin
          # Récupérer le PaymentIntent pour obtenir le charge_id
          payment_intent = ::Stripe::PaymentIntent.retrieve(contribution.payment_id)
          charge_id = payment_intent.latest_charge
          
          return false unless charge_id.present?
          
          # IMPORTANT: Si la contribution a été transférée, reverser le transfert d'abord
          # Stripe docs: "refunding a charge has no impact on any associated transfers"
          if contribution.stripe_transferred && contribution.stripe_transfer_id.present?
            begin
              ::Stripe::Transfer.create_reversal(
                contribution.stripe_transfer_id,
                {
                  metadata: {
                    contribution_id: contribution.id,
                    project_id: project.id,
                    reason: 'refund'
                  }
                }
              )
              Rails.logger.info "CampaignSettlement: Transfert #{contribution.stripe_transfer_id} reversé"
            rescue ::Stripe::StripeError => e
              Rails.logger.warn "CampaignSettlement: Impossible de reverser le transfert: #{e.message}"
              # Continue avec le remboursement même si le reversal échoue
            end
          end
          
          # Remboursement: on rembourse le montant brut MOINS les frais Stripe non récupérables
          # La commission plateforme est aussi retenue (comme annoncé dans les CGU)
          gross_amount      = contribution.value
          stripe_fee        = calculate_stripe_fee_for_contribution(contribution)
          fee_pct           = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
          platform_fee      = (gross_amount * fee_pct).round(2)
          
          # Remboursé = brut - frais Stripe réels (non-remboursables) - commission plateforme
          net_refund_amount = gross_amount - stripe_fee - platform_fee
          net_refund_amount = 0 if net_refund_amount < 0
          refund_amount_cents = (net_refund_amount * 100).to_i
          
          Rails.logger.info "CampaignSettlement: Remboursement contribution #{contribution.id}"
          Rails.logger.info "  - Montant brut: #{gross_amount}€"
          Rails.logger.info "  - Frais Stripe (non-remboursables): #{stripe_fee}€"
          Rails.logger.info "  - Commission plateforme (#{(fee_pct*100)}%): #{platform_fee}€"
          Rails.logger.info "  - Montant remboursé au contributeur: #{net_refund_amount}€"
          
          # Créer le remboursement PARTIEL (montant net seulement)
          refund = ::Stripe::Refund.create({
            charge: charge_id,
            amount: refund_amount_cents, # Remboursement PARTIEL en centimes
            metadata: {
              contribution_id: contribution.id,
              project_id: project.id,
              gross_amount: gross_amount,
              stripe_fee_retained: stripe_fee,
              platform_fee_retained: platform_fee,
              net_refunded: net_refund_amount,
              reason: 'campaign_cancelled'
            }
          })
          
          # Mettre à jour la contribution
          contribution.update(
            stripe_refunded: true,
            stripe_refund_id: refund.id,
            stripe_refund_amount: net_refund_amount # Stocker le montant réellement remboursé
          )
          
          # Changer l'état de la contribution (ignorer les erreurs de callbacks externes)
          begin
            contribution.refund! if contribution.respond_to?(:refund!) && contribution.can_refund?
          rescue => e
            Rails.logger.warn "CampaignSettlement: Impossible de changer l'état: #{e.message}"
            # Forcer l'état manuellement si la transition échoue
            contribution.update_column(:state, 'refunded') if contribution.respond_to?(:state)
          end
          
          # Notifier le contributeur avec le montant réel remboursé
          begin
            notify_contributor_refund(contribution, net_refund_amount, stripe_fee, platform_fee)
          rescue => e
            Rails.logger.warn "CampaignSettlement: Erreur notification: #{e.message}"
          end
          
          Rails.logger.info "CampaignSettlement: Contribution #{contribution.id} remboursée #{net_refund_amount}€ (refund #{refund.id})"
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

      def transferable_contributions
        stripe_contributions.where(state: 'confirmed')
                            .where(stripe_refunded: [false, nil])
                            .where(stripe_transferred: [false, nil])
      end

      def transferred_contributions
        stripe_contributions.where(state: 'confirmed')
                            .where(stripe_refunded: [false, nil])
                            .where(stripe_transferred: true)
      end

      def create_bank_payout_for_transferred_funds!
        return add_error("Le virement bancaire Stripe est déjà confirmé") if project.stripe_payout_status == 'paid'
        return add_error("Un virement bancaire Stripe est déjà en cours") if %w[pending in_transit].include?(project.stripe_payout_status)

        amounts_by_currency = transferred_amounts_by_currency
        subtract_existing_active_payouts!(amounts_by_currency)
        amounts_by_currency.reject! { |_currency, amount_cents| amount_cents.to_i <= 0 }
        return add_error("Aucun montant transféré disponible pour créer le virement bancaire") if amounts_by_currency.empty?

        balance = ::Stripe::Balance.retrieve({}, { stripe_account: project.stripe_account_id })
        created_count = 0

        amounts_by_currency.each do |currency, amount_cents|
          next if amount_cents.to_i <= 0

          available_cents = available_balance_cents(balance, currency)
          if available_cents < amount_cents
            @errors << "Solde Connect disponible insuffisant pour #{currency.upcase}: #{available_cents / 100.0} disponible, #{amount_cents / 100.0} requis. Créez le virement depuis le Dashboard Stripe quand les fonds seront disponibles."
            next
          end

          payout = ::Stripe::Payout.create(
            {
              amount: amount_cents,
              currency: currency,
              description: "Virement bancaire projet ##{project.id} - #{project.name.to_s.truncate(80)}",
              metadata: {
                project_id: project.id,
                user_id: project.user_id,
                platform: 'fiatope',
                source: 'admin_platform'
              }
            },
            { stripe_account: project.stripe_account_id }
          )

          @payouts << payout
          remember_project_payout!(payout, 'platform')
          created_count += 1
          Rails.logger.info "CampaignSettlement: Payout #{payout.id} créé pour projet #{project.id} (#{amount_cents / 100.0} #{currency.upcase})"
        end

        created_count > 0
      rescue ::Stripe::StripeError => e
        add_error("Création du virement bancaire Stripe impossible: #{e.message}")
      end

      def transferred_amounts_by_currency
        fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        transferred_contributions.each_with_object(Hash.new(0)) do |contribution, amounts|
          currency = contribution.stripe_transfer_currency.presence || project.currency.to_s.downcase.presence || 'eur'
          amount_cents = contribution.stripe_transfer_amount_cents.presence
          amount_cents ||= (contribution.value.to_f * (1 - fee_pct) * 100).to_i
          amounts[currency] += amount_cents.to_i
        end
      end

      def available_balance_cents(balance, currency)
        entry = Array(balance.available).find { |item| item.currency == currency }
        entry ? entry.amount.to_i : 0
      end

      def subtract_existing_active_payouts!(amounts_by_currency)
        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip).reject(&:blank?).uniq
        payout_ids.each do |payout_id|
          begin
            payout = ::Stripe::Payout.retrieve(payout_id, { stripe_account: project.stripe_account_id })
          rescue ::Stripe::StripeError => e
            Rails.logger.warn "CampaignSettlement: impossible de verifier payout #{payout_id} pour projet #{project.id}: #{e.message}"
            next
          end

          next unless %w[paid pending in_transit].include?(payout.status)
          currency = payout.currency.to_s.downcase
          amounts_by_currency[currency] -= payout.amount.to_i
        end
      end

      def remember_project_payout!(payout, source)
        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip)
        payout_ids << payout.id
        payout_ids = payout_ids.reject(&:blank?).uniq

        project.update(
          stripe_payout_id: payout.id,
          stripe_payout_ids: payout_ids.join(','),
          stripe_payout_status: payout.status,
          stripe_payout_source: source,
          stripe_payout_amount_cents: payout.amount,
          stripe_payout_currency: payout.currency,
          stripe_payout_arrival_date: payout_timestamp(payout.arrival_date),
          stripe_payout_failure_code: nil,
          stripe_payout_failure_message: nil,
          stripe_payout_failed_at: nil
        )
      end

      def payout_timestamp(timestamp)
        timestamp.present? ? Time.zone.at(timestamp) : nil
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
        
        if project.stripe_payout_status == 'paid'
          return add_error("Le virement bancaire Stripe est déjà confirmé")
        end

        if %w[pending in_transit].include?(project.stripe_payout_status)
          return add_error("Un virement bancaire Stripe est déjà en cours")
        end

        contributions = transferable_contributions
        if contributions.empty?
          already_transferred = stripe_contributions.where(stripe_transferred: true).count
          already_refunded = stripe_contributions.where(stripe_refunded: true).count
          if already_transferred > 0
            return true
          elsif already_refunded > 0
            return add_error("Toutes les contributions (#{already_refunded}) ont déjà été remboursées")
          else
            return add_error("Aucune contribution Stripe confirmée à transférer")
          end
        end
        
        true
      end
      
      # Validation pour le remboursement - vérifie les contributions INDIVIDUELLES
      # Note: On peut rembourser des contributions non transférées même si d'autres ont été transférées
      # @param contribution_ids [Array<Integer>, nil] IDs des contributions à vérifier (nil = toutes)
      def valid_for_refund?(contribution_ids = nil)
        unless project.present?
          return add_error("Projet non trouvé")
        end
        
        unless project.use_stripe?
          return add_error("Stripe n'est pas activé pour ce projet")
        end
        
        # Vérifier s'il reste des contributions remboursables:
        # - Confirmées
        # - NON remboursées (stripe_refunded = false ou nil)
        # - NON transférées (stripe_transferred = false ou nil)
        contributions = stripe_contributions.where(state: 'confirmed')
                                           .where(stripe_refunded: [false, nil])
                                           .where(stripe_transferred: [false, nil])
        
        # Filtrer par IDs si spécifiés
        contributions = contributions.where(id: contribution_ids) if contribution_ids.present?
        
        if contributions.empty?
          # Donner un message plus précis sur la raison
          total_stripe = stripe_contributions.count
          already_refunded = stripe_contributions.where(stripe_refunded: true).count
          already_transferred = stripe_contributions.where(stripe_transferred: true).count
          
          if already_transferred > 0 && already_refunded == 0
            return add_error("Toutes les contributions (#{already_transferred}) ont déjà été transférées au porteur")
          elsif already_refunded > 0 && already_transferred == 0
            return add_error("Toutes les contributions (#{already_refunded}) ont déjà été remboursées")
          elsif already_refunded > 0 && already_transferred > 0
            return add_error("Toutes les contributions ont été traitées (#{already_transferred} transférées, #{already_refunded} remboursées)")
          else
            return add_error("Aucune contribution Stripe confirmée à rembourser")
          end
        end
        
        true
      end
      
      def stripe_contributions
        project.contributions.where(payment_method: 'Stripe')
      end
      
      def calculate_platform_fee(gross_amount)
        # PLATFORM_FEE est le % TOTAL annoncé au porteur (inclut frais Stripe)
        # Ex: 4% → porteur reçoit 96% du brut, plateforme garde 4% (dont ~2.5% pour Stripe)
        fee_percentage = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        (gross_amount * fee_percentage).round(2)
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
          # Uniquement le project_id comme filtre d'unicité (valid column)
          # Le template calcule les montants depuis project.contributions directement
          project.notify_owner(:stripe_transfer_complete)
        rescue => e
          Rails.logger.warn "CampaignSettlement: Erreur notification transfert - #{e.message}"
        end
      end
      
      def notify_contributor_refund(contribution, net_amount = nil, stripe_fee = nil, platform_fee = nil)
        begin
          # Passer la contribution comme filtre d'unicité (contribution_id est une colonne valide)
          # Le template accède aux données via @notification.contribution
          contribution.notify_owner(:stripe_refund_complete)
        rescue => e
          Rails.logger.warn "CampaignSettlement: Erreur notification remboursement - #{e.message}"
        end
      end
    end
  end
end
