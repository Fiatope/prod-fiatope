module Neighborly
  module Stripe
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      before_action :verify_stripe_signature
      
      def create
        case @event.type
        # === CHECKOUT SESSIONS ===
        when 'checkout.session.completed'
          handle_checkout_completed(@event.data.object)
        when 'checkout.session.async_payment_succeeded'
          # Pour paiements différés (SEPA, etc.) - confirmation finale
          handle_async_payment_succeeded(@event.data.object)
        when 'checkout.session.async_payment_failed'
          # Pour paiements différés qui échouent
          handle_async_payment_failed(@event.data.object)
        # === PAYMENT INTENTS ===
        when 'payment_intent.succeeded'
          handle_payment_succeeded(@event.data.object)
        when 'payment_intent.payment_failed'
          handle_payment_failed(@event.data.object)
        # === CHARGES ===
        when 'charge.refunded'
          handle_charge_refunded(@event.data.object)
        when 'charge.dispute.created'
          handle_dispute_created(@event.data.object)
        # === CONNECT ACCOUNTS ===
        when 'account.updated'
          handle_account_updated(@event.data.object)
        # === TRANSFERS ===
        when 'transfer.created'
          handle_transfer_created(@event.data.object)
        when 'transfer.reversed'
          handle_transfer_reversed(@event.data.object)
        # === PAYOUTS (virement vers banque porteur) ===
        when 'payout.created', 'payout.updated'
          handle_payout_updated(@event.data.object)
        when 'payout.paid'
          handle_payout_paid(@event.data.object)
        when 'payout.failed', 'payout.canceled'
          handle_payout_failed(@event.data.object)
        else
          Rails.logger.info "Unhandled Stripe event type: #{@event.type}"
        end
        
        render json: { status: 'success' }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Stripe webhook error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Webhook processing failed' }, status: :bad_request
      end
      
      private
      
      def verify_stripe_signature
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']
        
        begin
          @event = ::Stripe::Webhook.construct_event(
            payload, sig_header, endpoint_secret
          )
        rescue JSON::ParserError => e
          Rails.logger.error "Stripe webhook JSON parse error: #{e.message}"
          render json: { error: 'Invalid payload' }, status: :bad_request
        rescue ::Stripe::SignatureVerificationError => e
          Rails.logger.error "Stripe webhook signature verification failed: #{e.message}"
          render json: { error: 'Invalid signature' }, status: :bad_request
        end
      end
      
      def handle_checkout_completed(session)
        project_id = session.metadata['project_id']
        user_id = session.metadata['user_id']
        contribution_id = session.metadata['contribution_id']
        amount = session.amount_total
        
        return unless project_id && user_id
        
        project = ::Project.find_by(id: project_id)
        user = ::User.find_by(id: user_id)
        
        return unless project && user
        
        # Si contribution_id existe, utiliser la contribution existante
        if contribution_id.present?
          contribution = ::Contribution.find_by(id: contribution_id)
          if contribution
            contribution.update(
              payment_method: 'Stripe',
              payment_id: session.payment_intent
            )
          else
            # Contribution supprimée entre-temps, en créer une nouvelle
            contribution = ::Contribution.create!(
              project: project,
              user: user,
              value: amount / 100.0,
              payment_method: 'Stripe',
              payment_id: session.payment_intent,
              state: 'pending'
            )
          end
        else
          # Pas de contribution existante, en créer une nouvelle
          contribution = ::Contribution.create!(
            project: project,
            user: user,
            value: amount / 100.0,
            payment_method: 'Stripe',
            payment_id: session.payment_intent,
            state: 'pending'
          )
        end
        
        stripe_order = contribution.create_stripe_order(
          payment_intent_id: session.payment_intent,
          checkout_session_id: session.id
        )
        
        Rails.logger.info "Checkout completed: Contribution #{contribution.id} (#{contribution_id.present? ? 'existing' : 'new'})"
      end
      
      def handle_payment_succeeded(payment_intent)
        stripe_order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
        return unless stripe_order
        
        stripe_order.mark_as_completed!(
          charge_id: payment_intent.charges.data.first&.id,
          transfer_id: payment_intent.transfer
        )
        
        if stripe_order.contribution && stripe_order.contribution.state != 'confirmed'
          begin
            stripe_order.contribution.confirm!
            Rails.logger.info "Webhook: Contribution #{stripe_order.contribution.id} confirmée"
          rescue => e
            Rails.logger.warn "Webhook: Impossible de confirmer contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Payment succeeded: Order #{stripe_order.id} marked as completed"
      end
      
      def handle_payment_failed(payment_intent)
        stripe_order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
        return unless stripe_order
        
        stripe_order.mark_as_failed!
        
        if stripe_order.contribution && stripe_order.contribution.state == 'pending'
          begin
            stripe_order.contribution.cancel!
            Rails.logger.info "Webhook: Contribution #{stripe_order.contribution.id} annulée"
          rescue => e
            Rails.logger.warn "Webhook: Impossible d'annuler contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Payment failed: Order #{stripe_order.id} marked as failed"
      end
      
      def handle_charge_refunded(charge)
        stripe_order = Order.find_by(stripe_charge_id: charge.id)
        return unless stripe_order
        
        stripe_order.update(status: 'refunded')
        
        if stripe_order.contribution && stripe_order.contribution.state == 'confirmed'
          begin
            stripe_order.contribution.refund!
            Rails.logger.info "Webhook: Contribution #{stripe_order.contribution.id} remboursée"
          rescue => e
            Rails.logger.warn "Webhook: Impossible de rembourser contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Charge refunded: Order #{stripe_order.id} marked as refunded"
      end
      
      def handle_account_updated(account)
        user = ::User.find_by(stripe_connect_account_id: account.id)
        return unless user
        
        ready_for_transfers = account_ready_for_transfers?(account)
        user.update(stripe_onboarding_complete: ready_for_transfers)
        Rails.logger.info "Account updated: User #{user.id} ready_for_transfers=#{ready_for_transfers}"

        if ready_for_transfers
          
          # CRITIQUE: Synchroniser tous les projets du porteur
          # C'est ici que la magie opère - quand l'onboarding est complété,
          # on s'assure que tous les projets ont le bon stripe_account_id
          sync_user_projects(user)
        end
      end
      
      # Synchronise le stripe_account_id sur TOUS les projets du porteur
      def sync_user_projects(user)
        return unless user.stripe_connect_account_id.present?
        
        synced_count = 0
        user.projects.find_each do |project|
          if project.stripe_account_id != user.stripe_connect_account_id
            project.update_columns(
              stripe_account_id: user.stripe_connect_account_id,
              use_stripe: true
            )
            synced_count += 1
          end
        end
        
        Rails.logger.info "Webhook: Synchronisé #{synced_count} projet(s) pour #{user.email} avec compte #{user.stripe_connect_account_id}"
      end
      
      def account_ready_for_transfers?(account)
        account.payouts_enabled &&
          stripe_value(account.capabilities, :transfers) == 'active' &&
          account_requirements_due(account).empty?
      end

      def account_requirements_due(account)
        requirements = account.requirements
        future_requirements = stripe_value(account, :future_requirements)
        (
          Array(stripe_value(requirements, :currently_due)) +
          Array(stripe_value(requirements, :past_due)) +
          Array(stripe_value(future_requirements, :currently_due)) +
          Array(stripe_value(future_requirements, :past_due))
        ).uniq
      end

      def stripe_value(object, key)
        return nil unless object
        return object[key] if object.respond_to?(:[]) && object[key].present?
        return object[key.to_s] if object.respond_to?(:[]) && object[key.to_s].present?
        return object.public_send(key) if object.respond_to?(key)

        nil
      end

      def handle_transfer_created(transfer)
        stripe_order = Order.find_by(stripe_payment_intent_id: transfer.source_transaction)
        return unless stripe_order
        
        stripe_order.update(stripe_transfer_id: transfer.id)
        Rails.logger.info "Transfer created: Order #{stripe_order.id} transfer #{transfer.id}"
      end
      
      # Paiement asynchrone réussi (SEPA, etc.)
      def handle_async_payment_succeeded(session)
        contribution_id = session.metadata['contribution_id']
        return unless contribution_id.present?
        
        contribution = ::Contribution.find_by(id: contribution_id)
        return unless contribution
        
        # Confirmer la contribution
        if contribution.state != 'confirmed'
          begin
            contribution.confirm!
            Rails.logger.info "Webhook: Async payment succeeded - Contribution #{contribution.id} confirmée"
          rescue => e
            Rails.logger.warn "Webhook: Impossible de confirmer contribution async: #{e.message}"
          end
        end
        
        # Mettre à jour le stripe_order si existe
        stripe_order = Order.find_by(stripe_checkout_session_id: session.id)
        stripe_order&.update(status: 'completed')
      end
      
      # Paiement asynchrone échoué (SEPA, etc.)
      def handle_async_payment_failed(session)
        contribution_id = session.metadata['contribution_id']
        return unless contribution_id.present?
        
        contribution = ::Contribution.find_by(id: contribution_id)
        return unless contribution
        
        # Annuler la contribution
        if contribution.state == 'pending'
          begin
            contribution.cancel!
            Rails.logger.info "Webhook: Async payment failed - Contribution #{contribution.id} annulée"
          rescue => e
            Rails.logger.warn "Webhook: Impossible d'annuler contribution async: #{e.message}"
          end
        end
        
        # Mettre à jour le stripe_order si existe
        stripe_order = Order.find_by(stripe_checkout_session_id: session.id)
        stripe_order&.update(status: 'failed')
      end
      
      # Litige/dispute créé - CRITIQUE pour la gestion financière
      def handle_dispute_created(dispute)
        charge_id = dispute.charge
        return unless charge_id.present?
        
        # Trouver la contribution via le stripe_order
        stripe_order = Order.find_by(stripe_charge_id: charge_id)
        return unless stripe_order
        
        contribution = stripe_order.contribution
        return unless contribution
        
        # Logger l'alerte - les litiges doivent être traités manuellement
        Rails.logger.error "DISPUTE CRÉÉ: Contribution #{contribution.id}, Projet #{contribution.project.name}, Montant #{contribution.value}€"
        Rails.logger.error "Dispute ID: #{dispute.id}, Raison: #{dispute.reason}"
        
        # Notifier l'admin (si méthode existe)
        begin
          AdminMailer.dispute_alert(contribution, dispute).deliver_later if defined?(AdminMailer)
        rescue => e
          Rails.logger.warn "Impossible d'envoyer alerte dispute: #{e.message}"
        end
      end
      
      def handle_payout_updated(payout)
        return handle_payout_paid(payout) if payout.status == 'paid'
        return handle_payout_failed(payout) if %w[failed canceled].include?(payout.status)

        project = find_project_for_payout(payout)
        unless project
          Rails.logger.warn "Webhook payout.#{payout.status}: projet introuvable pour payout #{payout.id}"
          return
        end

        update_project_payout_from_stripe!(project, payout)
        Rails.logger.info "Payout #{payout.id} mis a jour pour projet #{project.id}: #{payout.status}"
      end

      # Payout reussi: argent arrive sur le compte bancaire du porteur.
      # C'est le seul moment ou le projet Stripe peut devenir paid.
      def handle_payout_paid(payout)
        project = find_project_for_payout(payout)
        unless project
          Rails.logger.warn "Webhook payout.paid: projet introuvable pour payout #{payout.id}"
          return
        end

        already_finalized = project.state == 'paid' && project.stripe_payout_paid_at.present?
        account_id = connected_account_id.presence || project.stripe_account_id
        all_paid = all_project_payouts_paid?(project, payout, account_id)
        update_project_payout_from_stripe!(project, payout, status_override: (all_paid ? 'paid' : 'in_transit'))

        unless all_paid
          Rails.logger.info "Payout #{payout.id} paye, attente des autres payouts du projet #{project.id}"
          return
        end

        project.reload
        finalize_project_after_payout!(project)
        project.update_columns(stripe_settled_at: project.stripe_payout_paid_at || Time.zone.now)

        Rails.logger.info "PAYOUT PAID: projet #{project.id}, payout #{payout.id}, #{payout.amount / 100.0} #{payout.currency.to_s.upcase}"

        begin
          project.notify_owner(:stripe_payout_paid) unless already_finalized
        rescue => e
          Rails.logger.warn "Webhook payout.paid: notification email echouee: #{e.message}"
        end
      end

      # Payout echoue: le virement vers banque a echoue. Le projet reste en request_funds.
      def handle_payout_failed(payout)
        project = find_project_for_payout(payout)
        unless project
          Rails.logger.warn "Webhook payout.failed: projet introuvable pour payout #{payout.id}"
          return
        end

        update_project_payout_from_stripe!(project, payout)
        amount = payout.amount.to_i / 100.0
        failure_message = payout.failure_message.presence || payout.failure_code.presence || 'raison inconnue'
        Rails.logger.error "PAYOUT FAILED: projet #{project.id}, #{amount} #{payout.currency.to_s.upcase} - #{failure_message}"

        begin
          AdminMailer.payout_failed_alert(project.user, amount, failure_message).deliver_later if defined?(AdminMailer)
        rescue => e
          Rails.logger.warn "Webhook payout.failed: alerte admin echouee: #{e.message}"
        end
      end

      def connected_account_id
        @event.respond_to?(:account) ? @event.account : nil
      end

      def find_project_for_payout(payout)
        metadata_project_id = stripe_value(payout.metadata, :project_id)
        project = ::Project.find_by(id: metadata_project_id) if metadata_project_id.present?
        return project if project && payout_project_matches_connected_account?(project)

        description_project_id = project_id_from_payout_description(payout)
        project = ::Project.find_by(id: description_project_id) if description_project_id.present?
        return project if project && payout_project_matches_connected_account?(project)

        project = ::Project.find_by(stripe_payout_id: payout.id)
        return project if project

        project = ::Project.where("stripe_payout_ids LIKE ?", "%#{payout.id}%").first
        return project if project

        account_id = connected_account_id
        return nil unless account_id.present?

        user = ::User.find_by(stripe_connect_account_id: account_id)
        return nil unless user

        candidates = user.projects.where(stripe_settlement_type: 'transferred').order(updated_at: :desc).to_a
        candidates.reject! { |candidate| candidate.state == 'paid' && candidate.stripe_payout_status == 'paid' }
        candidates += user.projects.where(state: 'request_funds').order(updated_at: :desc).to_a
        candidates.uniq!
        exact_match = candidates.find do |candidate|
          stored_amount_matches = candidate.stripe_payout_amount_cents.to_i == payout.amount.to_i &&
                                  candidate.stripe_payout_currency.to_s.downcase == payout.currency.to_s.downcase
          expected_amount_matches = expected_project_payout_amount_cents(candidate, payout.currency).to_i == payout.amount.to_i
          stored_amount_matches || expected_amount_matches
        end
        return exact_match if exact_match

        Rails.logger.warn "Webhook payout #{payout.id}: metadata absente, fallback sur projet recent du compte #{account_id}" if candidates.size > 1
        candidates.first
      end

      def project_id_from_payout_description(payout)
        description = payout.respond_to?(:description) ? payout.description.to_s : ''
        description[/\b(?:project|projet)\s*#?\s*(\d+)\b/i, 1]
      end

      def payout_project_matches_connected_account?(project)
        account_id = connected_account_id
        return true if account_id.blank?

        project.stripe_account_id.to_s == account_id.to_s ||
          project.user&.stripe_connect_account_id.to_s == account_id.to_s
      end

      def update_project_payout_from_stripe!(project, payout, status_override: nil)
        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip)
        payout_ids << payout.id
        payout_ids = payout_ids.reject(&:blank?).uniq
        status = (status_override || payout.status).to_s
        failed_status = %w[failed canceled].include?(status)
        paid_status = status == 'paid'
        paid_at = paid_status ? (payout_timestamp(payout.arrival_date) || Time.zone.now) : project.stripe_payout_paid_at
        payout_source = stripe_value(payout.metadata, :source).presence || project.stripe_payout_source.presence || 'stripe_dashboard'

        project.update_columns(
          stripe_payout_id: payout.id,
          stripe_payout_ids: payout_ids.join(','),
          stripe_payout_status: status,
          stripe_payout_source: payout_source,
          stripe_payout_amount_cents: payout.amount,
          stripe_payout_currency: payout.currency,
          stripe_payout_arrival_date: payout_timestamp(payout.arrival_date),
          stripe_payout_paid_at: paid_at,
          stripe_payout_failed_at: failed_status ? Time.zone.now : nil,
          stripe_payout_failure_code: failed_status ? payout.failure_code : nil,
          stripe_payout_failure_message: failed_status ? payout.failure_message : nil
        )

        mark_dashboard_payout_transfer_if_needed!(project, payout, payout_source)
      end

      def expected_project_payout_amount_cents(project, currency)
        payout_candidate_contributions(project, currency).sum do |contribution|
          estimated_contribution_payout_amount_cents(contribution)
        end
      end

      def payout_candidate_contributions(project, currency)
        expected_currency = currency.to_s.downcase
        confirmed = project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                           .where(stripe_refunded: [false, nil])
        transferred = confirmed.where(stripe_transferred: true)
        source = transferred.exists? ? transferred : confirmed

        source.to_a.select do |contribution|
          contribution_currency = contribution.stripe_transfer_currency.presence || project.currency.to_s.downcase.presence || 'eur'
          contribution_currency.to_s.downcase == expected_currency
        end
      end

      def estimated_contribution_payout_amount_cents(contribution)
        fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        contribution.stripe_transfer_amount_cents.presence || (contribution.value.to_f * (1 - fee_pct) * 100).to_i
      end

      def mark_dashboard_payout_transfer_if_needed!(project, payout, payout_source)
        return unless payout_source == 'stripe_dashboard'
        return if project.stripe_settlement_type == 'transferred'

        contributions = payout_candidate_contributions(project, payout.currency)
        return if contributions.empty?

        expected_amount = contributions.sum { |contribution| estimated_contribution_payout_amount_cents(contribution) }
        tolerance_cents = [contributions.size, 2].max
        return unless expected_amount.positive? && (expected_amount - payout.amount.to_i).abs <= tolerance_cents

        contributions.each do |contribution|
          contribution.update_columns(
            stripe_transferred: true,
            stripe_transfer_amount_cents: estimated_contribution_payout_amount_cents(contribution),
            stripe_transfer_currency: payout.currency.to_s.downcase
          )
        end

        project.update_columns(
          stripe_settlement_type: 'transferred',
          stripe_transfer_created_at: project.stripe_transfer_created_at || Time.zone.now,
          stripe_settled_at: nil
        )
        Rails.logger.info "Payout #{payout.id}: reglement dashboard rattache au projet #{project.id} (#{contributions.size} contribution(s))"
      end

      def all_project_payouts_paid?(project, current_payout, account_id)
        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip)
        payout_ids << current_payout.id
        payout_ids = payout_ids.reject(&:blank?).uniq
        return current_payout.status == 'paid' if payout_ids.size <= 1
        return false unless account_id.present?

        payout_ids.all? do |payout_id|
          payout = payout_id == current_payout.id ? current_payout : ::Stripe::Payout.retrieve(payout_id, { stripe_account: account_id })
          payout.status == 'paid'
        end
      rescue ::Stripe::StripeError => e
        Rails.logger.warn "Verification payouts projet #{project.id} impossible: #{e.message}"
        false
      end

      def finalize_project_after_payout!(project)
        return if project.state == 'paid'

        if project.respond_to?(:can_push_to_paid?) && project.can_push_to_paid?
          project.push_to_paid!
        else
          Rails.logger.warn "Payout paid pour projet #{project.id}, mais transition paid impossible depuis state=#{project.state}"
        end
      end

      def payout_timestamp(timestamp)
        timestamp.present? ? Time.zone.at(timestamp) : nil
      end
      
      # Transfert inversé/annulé
      def handle_transfer_reversed(transfer)
        # Trouver la contribution via le transfer_id
        contribution = ::Contribution.find_by(stripe_transfer_id: transfer.id)
        
        if contribution
          contribution.update_columns(
            stripe_transferred: false,
            stripe_transfer_id: nil
          )
          Rails.logger.warn "Transfer reversed: Contribution #{contribution.id} - transfert annulé"
        end
        
        # Mettre à jour le projet si c'est le transfert principal
        project = ::Project.find_by(stripe_transfer_id: transfer.id)
        if project
          project.update_columns(
            stripe_transfer_id: nil,
            stripe_settlement_type: nil
          )
          Rails.logger.warn "Transfer reversed: Projet #{project.id} - règlement annulé"
        end
      end
    end
  end
end
