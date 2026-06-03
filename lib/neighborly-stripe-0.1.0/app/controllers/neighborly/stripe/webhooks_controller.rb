module Neighborly
  module Stripe
    class WebhooksController < ApplicationController
      class WebhookIntegrityError < StandardError; end

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
        metadata = session.metadata || {}
        project_id = metadata['project_id']
        user_id = metadata['user_id']
        contribution_id = metadata['contribution_id']
        amount = session.amount_total
        
        raise WebhookIntegrityError, 'Projet Checkout absent' if project_id.blank?
        raise WebhookIntegrityError, 'Utilisateur Checkout absent' if user_id.blank?
        raise WebhookIntegrityError, 'PaymentIntent Checkout absent' if session.payment_intent.blank?
        raise WebhookIntegrityError, 'Montant Checkout invalide' unless amount.to_i.positive?
        
        project = ::Project.find_by(id: project_id)
        user = ::User.find_by(id: user_id)
        
        raise WebhookIntegrityError, 'Projet local Checkout introuvable' unless project
        raise WebhookIntegrityError, 'Utilisateur local Checkout introuvable' unless user
        ensure_checkout_session_matches!(session, project, user)
        
        with_checkout_payment_lock(session.payment_intent) do
          contribution = ::Contribution.find_by(payment_id: session.payment_intent)
          if contribution
            ensure_checkout_contribution_matches!(contribution, project, user, session)
          else
            contribution = ::Contribution.find_by(id: contribution_id) if contribution_id.present?
            ensure_checkout_contribution_matches!(contribution, project, user, session) if contribution
            if contribution&.payment_id.present? && contribution.payment_id != session.payment_intent
              Rails.logger.warn "Checkout duplicate payment: contribution #{contribution.id} already linked to #{contribution.payment_id}; recording #{session.payment_intent} separately"
              contribution = nil
            end

            contribution ||= create_checkout_contribution(project, user, amount, session)
            contribution.update!(payment_method: 'Stripe', payment_id: session.payment_intent)
          end

          stripe_order = contribution.create_stripe_order(
            payment_intent_id: session.payment_intent,
            checkout_session_id: session.id
          )

          handle_payment_succeeded(::Stripe::PaymentIntent.retrieve(session.payment_intent)) if session.payment_status == 'paid'

          Rails.logger.info "Checkout completed: Contribution #{contribution.id} (#{contribution_id.present? ? 'existing' : 'new'})"
        end
      end

      def create_checkout_contribution(project, user, amount, session)
        ::Contribution.create!(
          project: project,
          user: user,
          value: amount / 100.0,
          payment_method: 'Stripe',
          payment_id: session.payment_intent,
          state: 'pending'
        )
      end

      def ensure_checkout_session_matches!(session, project, user)
        expected_currency = project.currency.presence&.downcase || 'eur'
        if session.client_reference_id.present? && session.client_reference_id.to_s != user.id.to_s
          raise WebhookIntegrityError, 'Reference client Checkout incompatible'
        end
        raise WebhookIntegrityError, 'Devise Checkout incompatible' unless session.currency.to_s.downcase == expected_currency
      end

      def ensure_checkout_contribution_matches!(contribution, project, user, session)
        raise WebhookIntegrityError, 'Projet de contribution incompatible' unless contribution.project_id == project.id
        raise WebhookIntegrityError, 'Utilisateur de contribution incompatible' unless contribution.user_id == user.id
        raise WebhookIntegrityError, 'Montant de contribution incompatible' unless (contribution.value.to_f * 100).round == session.amount_total.to_i
      end

      def with_checkout_payment_lock(payment_intent_id)
        ::Contribution.transaction do
          connection = ::Contribution.connection
          lock_name = "stripe-checkout:#{payment_intent_id}"
          connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote(lock_name)}))")
          yield
        end
      end
      
      def handle_payment_succeeded(payment_intent)
        stripe_order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
        contribution = ::Contribution.find_by(payment_id: payment_intent.id)
        contribution ||= stripe_order&.contribution
        return unless contribution || stripe_order
        charge_id = payment_intent_charge_id(payment_intent)
        stripe_order&.mark_as_completed!(
          charge_id: charge_id,
          transfer_id: stripe_value(payment_intent, :transfer)
        )
        contribution.update_column(:stripe_charge_id, charge_id) if contribution && charge_id.present?
        
        if contribution && contribution.state != 'confirmed'
          begin
            contribution.confirm!
            Rails.logger.info "Webhook: Contribution #{contribution.id} confirmee"
          rescue => e
            Rails.logger.warn "Webhook: Impossible de confirmer contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Payment succeeded: PaymentIntent #{payment_intent.id} processed"
      end
      
      def handle_payment_failed(payment_intent)
        stripe_order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
        contribution = ::Contribution.find_by(payment_id: payment_intent.id)
        contribution ||= stripe_order&.contribution
        return unless contribution || stripe_order

        stripe_order&.mark_as_failed!
        
        if contribution && contribution.state == 'pending'
          begin
            contribution.cancel!
            Rails.logger.info "Webhook: Contribution #{contribution.id} annulee"
          rescue => e
            Rails.logger.warn "Webhook: Impossible d'annuler contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Payment failed: PaymentIntent #{payment_intent.id} processed"
      end
      
      def handle_charge_refunded(charge)
        stripe_order = Order.find_by(stripe_charge_id: charge.id)
        contribution = ::Contribution.find_by(stripe_charge_id: charge.id)
        contribution ||= ::Contribution.find_by(payment_id: stripe_value(charge, :payment_intent))
        contribution ||= stripe_order&.contribution
        return unless contribution || stripe_order

        if contribution
          refund = stripe_refund_from_charge(charge)
          fully_refunded = charge_fully_refunded?(charge)
          expected_partial_refund = expected_platform_partial_refund?(contribution, refund)
          updates = {}
          updates[:stripe_refund_id] = refund.id if refund.respond_to?(:id) && refund.id.present?
          if contribution.respond_to?(:stripe_refund_amount=)
            updates[:stripe_refund_amount] = stripe_value(charge, :amount_refunded).to_i / 100.0
          end

          unless fully_refunded || expected_partial_refund
            contribution.update_columns(updates) if updates.any?
            mark_project_for_manual_review!(
              contribution.project,
              "remboursement partiel externe sur charge #{charge.id}"
            )
            Rails.logger.warn "Charge partially refunded: Charge #{charge.id} requires manual review"
            return
          end

          stripe_order&.update(status: 'refunded')
          updates[:stripe_refunded] = true
          contribution.update_columns(updates)
        end

        if contribution && contribution.state == 'confirmed'
          begin
            contribution.refund!
            Rails.logger.info "Webhook: Contribution #{contribution.id} remboursee"
          rescue => e
            Rails.logger.warn "Webhook: Impossible de rembourser contribution: #{e.message}"
          end
        end
        
        Rails.logger.info "Charge refunded: Charge #{charge.id} processed"
      end
      
      def handle_account_updated(account)
        user = ::User.find_by(stripe_connect_account_id: account.id)
        return unless user
        
        ready_for_transfers = account_ready_for_transfers?(account)
        cache_stripe_account_status!(user, account, ready_for_transfers)
        Rails.logger.info "Account updated: User #{user.id} ready_for_transfers=#{ready_for_transfers}"

        if ready_for_transfers
          user.clear_payout_required_kyc_types! if user.respond_to?(:clear_payout_required_kyc_types!)
          
          # CRITIQUE: Synchroniser tous les projets du porteur
          # C'est ici que la magie opère - quand l'onboarding est complété,
          # on s'assure que tous les projets ont le bon stripe_account_id
          sync_user_projects(user)
        else
          due = account_requirements_due(account)
          user.remember_payout_required_kyc_types_from_requirements(due) if user.respond_to?(:remember_payout_required_kyc_types_from_requirements)
          unlock_payout_profiles_for_required_updates(user, account, due)
        end
      end
      
      # Synchronise le stripe_account_id sur TOUS les projets du porteur
      def sync_user_projects(user)
        return unless user.stripe_connect_account_id.present?
        
        synced_count = 0
        skipped_count = 0
        user.projects.find_each do |project|
          if stripe_project_account_locked?(project)
            skipped_count += 1
            next
          end

          if project.stripe_account_id != user.stripe_connect_account_id
            project.update_columns(
              stripe_account_id: user.stripe_connect_account_id,
              use_stripe: true
            )
            synced_count += 1
          end
        end
        
        Rails.logger.info "Webhook: Synchronise #{synced_count} projet(s) pour #{user.email} avec compte #{user.stripe_connect_account_id}; #{skipped_count} projet(s) deja en reglement ignores"
      end
      
      def cache_stripe_account_status!(user, account, ready_for_transfers)
        attrs = { stripe_onboarding_complete: ready_for_transfers }
        attrs[:stripe_account_type] = account.type if user.respond_to?(:stripe_account_type=)
        attrs[:stripe_charges_enabled] = account.charges_enabled if user.respond_to?(:stripe_charges_enabled=)
        attrs[:stripe_payouts_enabled] = account.payouts_enabled if user.respond_to?(:stripe_payouts_enabled=)
        user.update_columns(attrs)
      end

      def unlock_payout_profiles_for_required_updates(user, account, due)
        return unless account_needs_payout_profile_update?(account, due)

        projects = user.projects.where(state: 'request_funds').to_a
        if ::Project.column_names.include?('stripe_payout_status')
          projects += user.projects.where(stripe_payout_status: %w[failed canceled]).to_a
        end
        projects.uniq!
        return if projects.empty?

        Rails.cache.write(
          payout_profile_edit_unlock_cache_key(user),
          { unlocked_at: Time.current.to_i, source: 'account.updated' },
          expires_in: 14.days
        )

        projects.each do |project|
          project.update_column(:state, 'waiting_funds') if project.state == 'request_funds'
          notify_payout_profile_update_required(project)
        end
      rescue => e
        Rails.logger.warn "Webhook account.updated: impossible d ouvrir la correction du profil de retrait pour user #{user.id}: #{e.message}"
      end

      def account_needs_payout_profile_update?(account, due)
        due.any? ||
          Array(stripe_value(account.requirements, :errors)).any? ||
          stripe_value(account.requirements, :disabled_reason).present?
      end

      def payout_profile_edit_unlock_cache_key(user)
        "payout_profile_edit_unlock:user:#{user.id}"
      end

      def notify_payout_profile_update_required(project)
        cache_key = "payout_profile_update_required:auto:project:#{project.id}"
        return false if Rails.cache.read(cache_key).present?

        ::Notification.notify_once(
          :payout_profile_update_required,
          project.user,
          { project_id: project.id },
          project: project
        )
        Rails.cache.write(cache_key, true, expires_in: 14.days)
        true
      rescue => e
        Rails.logger.warn "Webhook account.updated: notification correction profil retrait echouee pour project #{project.id}: #{e.message}"
        false
      end

      def unlock_payout_profile_after_payout_failure(project)
        Rails.cache.write(
          payout_profile_edit_unlock_cache_key(project.user),
          { unlocked_at: Time.current.to_i, source: 'payout.failed' },
          expires_in: 14.days
        )
        notify_payout_profile_update_required(project)
      rescue => e
        Rails.logger.warn "Webhook payout.failed: impossible d ouvrir la correction du profil de retrait pour project #{project.id}: #{e.message}"
      end

      def stripe_project_account_locked?(project)
        settlement_type = project.respond_to?(:stripe_settlement_type) ? project.stripe_settlement_type.to_s : ''
        payout_status = project.respond_to?(:stripe_payout_status) ? project.stripe_payout_status.to_s : ''
        payout_id = project.respond_to?(:stripe_payout_id) ? project.stripe_payout_id : nil

        settlement_type == 'transferred' ||
          payout_id.present? ||
          %w[pending in_transit paid failed canceled].include?(payout_status)
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

      def payment_intent_charge_id(payment_intent)
        latest_charge = stripe_value(payment_intent, :latest_charge)
        return latest_charge.id if latest_charge.respond_to?(:id)
        return latest_charge if latest_charge.present?

        charges = stripe_value(payment_intent, :charges)
        charge = charges.data.first if charges.respond_to?(:data) && charges.data.respond_to?(:first)
        charge.respond_to?(:id) ? charge.id : charge
      end

      def stripe_refund_from_charge(charge)
        refunds = stripe_value(charge, :refunds)
        return refunds.data.first if refunds.respond_to?(:data) && refunds.data.present?

        ::Stripe::Refund.list({ charge: charge.id, limit: 1 }).data.first
      rescue ::Stripe::StripeError => e
        Rails.logger.warn "Charge #{charge.id}: recuperation du remboursement Stripe impossible: #{e.message}"
        nil
      end

      def charge_fully_refunded?(charge)
        return true if stripe_value(charge, :refunded) == true

        amount = stripe_value(charge, :amount).to_i
        amount.positive? && stripe_value(charge, :amount_refunded).to_i >= amount
      end

      def expected_platform_partial_refund?(contribution, refund)
        return true if contribution.respond_to?(:stripe_refunded?) && contribution.stripe_refunded?
        return false unless refund

        metadata = stripe_value(refund, :metadata)
        stripe_value(metadata, :contribution_id).to_s == contribution.id.to_s &&
          stripe_value(metadata, :reason).to_s == 'campaign_cancelled'
      end

      def handle_transfer_created(transfer)
        contribution = ::Contribution.find_by(stripe_charge_id: transfer.source_transaction)
        stripe_order = Order.find_by(stripe_charge_id: transfer.source_transaction)
        stripe_order ||= contribution&.stripe_order if contribution.respond_to?(:stripe_order)
        return unless contribution || stripe_order
        contribution&.update_columns(
          stripe_transferred: true,
          stripe_transfer_id: transfer.id
        )
        stripe_order&.update(stripe_transfer_id: transfer.id)
        Rails.logger.info "Transfer created: #{transfer.id} for contribution #{contribution&.id || 'unknown'}"
      end
      
      # Paiement asynchrone réussi (SEPA, etc.)
      def handle_async_payment_succeeded(session)
        contribution = checkout_contribution_from_metadata!(session)
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
        contribution = checkout_contribution_from_metadata!(session)
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

      def checkout_contribution_from_metadata!(session)
        metadata = session.metadata || {}
        contribution_id = metadata['contribution_id']
        return if contribution_id.blank?

        project_id = metadata['project_id']
        user_id = metadata['user_id']
        raise WebhookIntegrityError, 'Projet Checkout async absent' if project_id.blank?
        raise WebhookIntegrityError, 'Utilisateur Checkout async absent' if user_id.blank?

        contribution = ::Contribution.find_by(id: contribution_id)
        return unless contribution

        raise WebhookIntegrityError, 'Projet de contribution async incompatible' unless contribution.project_id.to_s == project_id.to_s
        raise WebhookIntegrityError, 'Utilisateur de contribution async incompatible' unless contribution.user_id.to_s == user_id.to_s

        ensure_checkout_session_matches!(session, contribution.project, contribution.user)
        ensure_checkout_contribution_matches!(contribution, contribution.project, contribution.user, session)
        contribution
      end
      
      # Litige/dispute créé - CRITIQUE pour la gestion financière
      def handle_dispute_created(dispute)
        charge_id = dispute.charge
        return unless charge_id.present?
        
        contribution = ::Contribution.find_by(stripe_charge_id: charge_id)
        contribution ||= Order.find_by(stripe_charge_id: charge_id)&.contribution
        return unless contribution

        remember_dispute!(contribution, dispute)
        mark_project_for_manual_review!(
          contribution.project,
          "litige #{dispute.id} sur contribution #{contribution.id}"
        )
        
        # Logger l'alerte - les litiges doivent être traités manuellement
        Rails.logger.error "DISPUTE CRÉÉ: Contribution #{contribution.id}, Projet #{contribution.project.name}, Montant #{contribution.value}€"
        Rails.logger.error "Dispute ID: #{dispute.id}, Raison: #{dispute.reason}"
        
        if contribution.stripe_transferred && contribution.stripe_transfer_id.present?
          begin
            ::Stripe::Transfer.create_reversal(
              contribution.stripe_transfer_id,
              {
                metadata: {
                  contribution_id: contribution.id,
                  dispute_id: dispute.id,
                  reason: 'dispute_created'
                }
              }
            )

            Rails.logger.error "Transfert #{contribution.stripe_transfer_id} reverse suite au litige"
          rescue ::Stripe::StripeError => e
            Rails.logger.error "Impossible de reverser le transfert #{contribution.stripe_transfer_id}: #{e.message}"
          end
        end

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
        payout_source = stripe_value(payout.metadata, :source).presence || project.stripe_payout_source.presence || 'stripe_dashboard'
        mark_dashboard_payout_transfer_if_needed!(project, payout, payout_source)
        project.reload
        account_id = connected_account_id.presence || project.stripe_account_id
        all_paid = all_project_payouts_paid?(project, payout, account_id)
        status =
          if all_paid
            'paid'
          elsif payout.status == 'paid' &&
                (payout_source == 'stripe_dashboard' ||
                 (!project_has_untransferred_confirmed_contributions?(project) &&
                  !project_has_outstanding_payouts?(project, payout, account_id)))
            'manual_review'
          else
            incomplete_project_payout_status(project)
          end
        update_project_payout_from_stripe!(project, payout, status_override: status)

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
        reopen_project_after_payout_failure!(project)
        unlock_payout_profile_after_payout_failure(project)
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

        project = ::Project.where(
          "EXISTS (SELECT 1 FROM unnest(string_to_array(COALESCE(projects.stripe_payout_ids, ''), ',')) AS stored_payout_id WHERE btrim(stored_payout_id) = ?)",
          payout.id.to_s
        ).first
        return project if project

        account_id = connected_account_id
        return nil unless account_id.present?

        user = ::User.find_by(stripe_connect_account_id: account_id)
        return nil unless user

        candidates = user.projects.where(stripe_settlement_type: 'transferred').order(updated_at: :desc).to_a
        candidates.reject! { |candidate| candidate.state == 'paid' && candidate.stripe_payout_status == 'paid' }
        candidates += user.projects.where(state: 'request_funds').order(updated_at: :desc).to_a
        candidates.uniq!
        exact_matches = candidates.select do |candidate|
          stored_amount_matches = candidate.stripe_payout_amount_cents.to_i == payout.amount.to_i &&
                                  candidate.stripe_payout_currency.to_s.downcase == payout.currency.to_s.downcase
          expected_amount_matches = expected_project_payout_amount_cents(candidate, payout.currency).to_i == payout.amount.to_i
          stored_amount_matches || expected_amount_matches
        end
        return exact_matches.first if exact_matches.size == 1

        if exact_matches.size > 1
          Rails.logger.warn "Webhook payout #{payout.id}: rattachement ambigu pour compte #{account_id}. Ajoutez l'identifiant du projet dans la description du payout."
          return nil
        end

        Rails.logger.warn "Webhook payout #{payout.id}: rattachement refuse pour compte #{account_id}. Ajoutez l'identifiant du projet dans la description du payout."
        nil
      end

      def project_id_from_payout_description(payout)
        description = payout.respond_to?(:description) ? payout.description.to_s : ''
        description[/\b(?:project|projet|cagnotte|campagne)\s*#?\s*(\d+)\b/i, 1]
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

      def reopen_project_after_payout_failure!(project)
        attrs = {
          stripe_payout_paid_at: nil,
          stripe_settled_at: nil
        }
        attrs[:state] = 'request_funds' if project.state == 'paid'

        project.update_columns(attrs)
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
        return false if project_has_untransferred_confirmed_contributions?(project)

        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip)
        payout_ids << current_payout.id
        payout_ids = payout_ids.reject(&:blank?).uniq
        return false if payout_ids.size > 1 && account_id.blank?

        payouts = payout_ids.map do |payout_id|
          payout_id == current_payout.id ? current_payout : ::Stripe::Payout.retrieve(payout_id, { stripe_account: account_id })
        end
        active_payouts = payouts.reject { |payout| %w[failed canceled].include?(payout.status) }
        return false if active_payouts.empty? || active_payouts.any? { |payout| payout.status != 'paid' }

        paid_payout_amounts_cover_transfers?(project, active_payouts)
      rescue ::Stripe::StripeError => e
        Rails.logger.warn "Verification payouts projet #{project.id} impossible: #{e.message}"
        false
      end

      def paid_payout_amounts_cover_transfers?(project, paid_payouts)
        expected_by_currency = Hash.new(0)
        transferred = project.contributions.where(payment_method: 'Stripe', state: 'confirmed', stripe_transferred: true)
                             .where(stripe_refunded: [false, nil])
        transferred.each do |contribution|
          currency = contribution.stripe_transfer_currency.presence || project.currency.to_s.downcase.presence || 'eur'
          expected_by_currency[currency.to_s.downcase] += estimated_contribution_payout_amount_cents(contribution).to_i
        end
        return false if expected_by_currency.empty?

        paid_by_currency = Hash.new(0)
        paid_payouts.each { |payout| paid_by_currency[payout.currency.to_s.downcase] += payout.amount.to_i }
        tolerance_cents = [transferred.size, 2].max
        expected_by_currency.keys.sort == paid_by_currency.keys.sort &&
          expected_by_currency.all? { |currency, amount| (paid_by_currency[currency] - amount).abs <= tolerance_cents }
      end

      def project_has_outstanding_payouts?(project, current_payout, account_id)
        payout_ids = project.stripe_payout_ids.to_s.split(',').map(&:strip)
        payout_ids << current_payout.id
        payout_ids.reject(&:blank?).uniq.any? do |payout_id|
          payout = payout_id == current_payout.id ? current_payout : ::Stripe::Payout.retrieve(payout_id, { stripe_account: account_id })
          %w[pending in_transit].include?(payout.status)
        end
      rescue ::Stripe::StripeError => e
        Rails.logger.warn "Verification payouts en cours projet #{project.id} impossible: #{e.message}"
        true
      end

      def incomplete_project_payout_status(project)
        project_has_untransferred_confirmed_contributions?(project) ? 'requires_payout' : 'in_transit'
      end

      def project_has_untransferred_confirmed_contributions?(project)
        project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
               .where(stripe_refunded: [false, nil], stripe_transferred: [false, nil])
               .exists?
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
      
      def handle_transfer_reversed(transfer)
        contribution = ::Contribution.find_by(stripe_transfer_id: transfer.id)
        project = contribution&.project || ::Project.find_by(stripe_transfer_id: transfer.id)
        fully_reversed = transfer_fully_reversed?(transfer)

        if contribution
          if fully_reversed
            contribution.update_columns(
              stripe_transferred: false,
              stripe_transfer_id: nil
            )
            Rails.logger.warn "Transfer reversed: Contribution #{contribution.id} - transfert annule"
          else
            Rails.logger.warn "Transfer partially reversed: Contribution #{contribution.id} - rapprochement manuel requis"
          end
        end

        if project
          clear_project_transfer_after_full_reversal!(project, transfer.id) if fully_reversed
          mark_project_for_manual_review!(
            project,
            fully_reversed ? "inversion du transfert #{transfer.id}" : "inversion partielle du transfert #{transfer.id}"
          )
        end
      end

      def transfer_fully_reversed?(transfer)
        return true if stripe_value(transfer, :reversed) == true

        amount = stripe_value(transfer, :amount).to_i
        amount.positive? && stripe_value(transfer, :amount_reversed).to_i >= amount
      end

      def clear_project_transfer_after_full_reversal!(project, reversed_transfer_id)
        return unless project.stripe_transfer_id.to_s == reversed_transfer_id.to_s

        remaining_transfer = project.contributions.where(stripe_transferred: true).where.not(stripe_transfer_id: nil).first
        project.update_columns(
          stripe_transfer_id: remaining_transfer&.stripe_transfer_id,
          stripe_settlement_type: remaining_transfer ? project.stripe_settlement_type : nil
        )
      end

      def remember_dispute!(contribution, dispute)
        contribution.update_column(:stripe_dispute_id, dispute.id) if contribution.respond_to?(:stripe_dispute_id=)
      end

      def mark_project_for_manual_review!(project, reason)
        return unless project

        attrs = {
          stripe_payout_status: 'manual_review',
          stripe_settled_at: nil
        }
        attrs[:state] = 'request_funds' if project.state == 'paid'
        project.update_columns(attrs)
        Rails.logger.warn "Projet #{project.id}: rapprochement manuel requis (#{reason})"
      end
    end
  end
end
