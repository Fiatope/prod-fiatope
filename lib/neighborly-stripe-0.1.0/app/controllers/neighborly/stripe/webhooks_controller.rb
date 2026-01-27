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
        
        if account.charges_enabled && account.payouts_enabled
          user.update(stripe_onboarding_complete: true)
          Rails.logger.info "Account updated: User #{user.id} onboarding complete"
          
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
