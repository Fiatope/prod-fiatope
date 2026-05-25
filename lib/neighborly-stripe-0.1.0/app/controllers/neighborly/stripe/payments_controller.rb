module Neighborly
  module Stripe
    class PaymentsController < ::ApplicationController
      before_action :authenticate_user!, except: [:success, :cancel]
      layout false, only: [:success]
      
      helper_method :root_path
      
      def root_path
        main_app.root_path
      end
      
      def new
        @project = ::Project.find(params[:project_id])
        @contribution = @project.contributions.find(params[:contribution_id]) if params[:contribution_id].present?
        @amount = @contribution&.value || params[:amount].to_f
        
        unless @project.use_stripe?
          flash[:alert] = I18n.t('stripe.project_not_ready', default: 'Ce projet ne peut pas encore accepter les paiements en ligne')
          redirect_to "/projects/#{@project.permalink}" and return
        end
        
        # Créer directement la session Stripe Checkout et rediriger
        begin
          amount_cents = (@amount * 100).to_i
          
          # Vérifier si le compte Connect peut recevoir des transferts
          connect_ready = false
          if @project.stripe_account_id.present?
            begin
              account = ::Stripe::Account.retrieve(@project.stripe_account_id)
              connect_ready = account_ready_for_transfers?(account)
            rescue ::Stripe::StripeError
              connect_ready = false
            end
          end
          
          # Construire URL image valide (Stripe exige URL absolue https)
          image_url = nil
          if @project.uploaded_image.present?
            img = @project.uploaded_image.url
            if img.present?
              if img.start_with?('http')
                image_url = img
              elsif img.start_with?('/')
                image_url = "#{request.base_url}#{img}"
              end
            end
          end
          
          product_data = {
            name: @project.name.presence || "Projet #{@project.id}",
            description: I18n.t('stripe.contribution_description', 
              project: @project.name, 
              default: "Contribution au projet #{@project.name}")[0..499]
          }
          product_data[:images] = [image_url] if image_url.present? && image_url.start_with?('https')
          
          session_params = {
            payment_method_types: ['card'],
            line_items: [{
              price_data: {
                currency: @project.currency.presence&.downcase || 'eur',
                product_data: product_data,
                unit_amount: amount_cents
              },
              quantity: 1
            }],
            mode: 'payment',
            success_url: "#{request.base_url}/stripe/projects/#{@project.id}/payments/success?session_id={CHECKOUT_SESSION_ID}",
            cancel_url: "#{request.base_url}/stripe/projects/#{@project.id}/payments/cancel",
            customer: current_user.stripe_customer.id,
            client_reference_id: current_user.id.to_s,
            metadata: {
              # CRITIQUE: user_id requis par méthode success pour comptabilisation
              user_id: current_user.id.to_s,
              contribution_id: @contribution&.id.to_s,
              # Metadata enrichies pour filtrage Stripe
              project_id: @project.id.to_s,
              project_name: @project.name.to_s[0..99],
              project_permalink: @project.permalink.to_s,
              platform: determine_platform,
              project_owner_id: @project.user_id.to_s,
              project_owner_name: @project.user&.display_name.to_s[0..99],
              project_owner_email: @project.user&.email.to_s,
              contributor_id: current_user.id.to_s,
              contributor_name: current_user.display_name.to_s[0..99],
              contributor_email: current_user.email.to_s,
              currency: @project.currency.presence || 'EUR',
              amount: @amount.to_s
            }
          }
          
          # CROWDFUNDING: PAS de transfert automatique!
          # L'argent reste sur le compte plateforme jusqu'à validation admin
          # L'admin utilise CampaignSettlement pour transférer manuellement
          session_params[:payment_intent_data] = {
            transfer_group: "project_#{@project.id}",
            metadata: {
              project_id: @project.id.to_s,
              project_name: @project.name.to_s[0..99],
              project_permalink: @project.permalink.to_s,
              platform: determine_platform,
              project_owner_id: @project.user_id.to_s,
              project_owner_name: @project.user&.display_name.to_s[0..99],
              project_owner_email: @project.user&.email.to_s,
              contributor_id: current_user.id.to_s,
              contributor_name: current_user.display_name.to_s[0..99],
              contributor_email: current_user.email.to_s,
              contribution_id: @contribution&.id.to_s,
              currency: @project.currency.presence || 'EUR',
              amount: @amount.to_s,
              # Stocker l'ID du compte Connect pour transfert futur par admin
              destination_account: connect_ready ? @project.stripe_account_id : nil
            }
          }
          
          if connect_ready
            Rails.logger.info "Stripe CROWDFUNDING: Paiement sur compte plateforme (transfert manuel admin requis vers #{@project.stripe_account_id})"
          else
            Rails.logger.info "Stripe: Paiement direct - Compte Connect non prêt"
          end
          
          session = ::Stripe::Checkout::Session.create(session_params)
          
          redirect_to session.url, allow_other_host: true
        rescue ::Stripe::StripeError => e
          Rails.logger.error "Stripe payment error: #{e.message}"
          flash[:alert] = I18n.t('stripe.payment_error', error: e.message, default: "Erreur de paiement : #{e.message}")
          redirect_to "/projects/#{@project.permalink}"
        end
      end
      
      def create
        @project = ::Project.find(params[:project_id])
        
        # Si contribution_id fourni, utiliser cette contribution existante
        if params[:contribution_id].present?
          @contribution = @project.contributions.find(params[:contribution_id])
          @amount = @contribution.value
          
          unless current_user == @contribution.user
            flash[:alert] = "Non autorisé"
            redirect_to "/projects/#{@project.permalink}" and return
          end
        else
          @amount = params[:amount].to_f
        end
        
        unless @project.use_stripe?
          flash[:alert] = I18n.t('stripe.project_not_ready', default: 'Ce projet ne peut pas encore accepter les paiements en ligne')
          redirect_to "/projects/#{@project.permalink}" and return
        end
        
        begin
          amount_cents = (@amount * 100).to_i
          platform_fee = @project.platform_fee_amount(amount_cents)
          
          # Construire URL image valide pour action create aussi
          image_url_create = nil
          if @project.uploaded_image.present?
            img = @project.uploaded_image.url
            if img.present?
              if img.start_with?('http')
                image_url_create = img
              elsif img.start_with?('/')
                image_url_create = "#{request.base_url}#{img}"
              end
            end
          end
          
          product_data_create = {
            name: @project.name.presence || "Projet #{@project.id}",
            description: I18n.t('stripe.contribution_description', 
              project: @project.name, 
              default: "Contribution au projet #{@project.name}")[0..499]
          }
          product_data_create[:images] = [image_url_create] if image_url_create.present? && image_url_create.start_with?('https')
          
          # Vérifier si Connect est prêt
          connect_ready_create = false
          if @project.stripe_account_id.present?
            begin
              account = ::Stripe::Account.retrieve(@project.stripe_account_id)
              connect_ready_create = account_ready_for_transfers?(account)
            rescue ::Stripe::StripeError
              connect_ready_create = false
            end
          end
          
          create_session_params = {
            payment_method_types: ['card'],
            line_items: [{
              price_data: {
                currency: @project.currency.presence&.downcase || 'eur',
                product_data: product_data_create,
                unit_amount: amount_cents
              },
              quantity: 1
            }],
            mode: 'payment',
            success_url: "#{request.base_url}/stripe/projects/#{@project.id}/payments/success?session_id={CHECKOUT_SESSION_ID}",
            cancel_url: "#{request.base_url}/stripe/projects/#{@project.id}/payments/cancel",
            customer: current_user.stripe_customer.id,
            client_reference_id: current_user.id.to_s,
            metadata: {
              # CRITIQUE: user_id requis par méthode success pour comptabilisation
              user_id: current_user.id.to_s,
              contribution_id: @contribution&.id.to_s,
              # Metadata enrichies pour filtrage Stripe
              project_id: @project.id.to_s,
              project_name: @project.name.to_s[0..99],
              project_permalink: @project.permalink.to_s,
              platform: determine_platform,
              project_owner_id: @project.user_id.to_s,
              project_owner_name: @project.user&.display_name.to_s[0..99],
              project_owner_email: @project.user&.email.to_s,
              contributor_id: current_user.id.to_s,
              contributor_name: current_user.display_name.to_s[0..99],
              contributor_email: current_user.email.to_s,
              currency: @project.currency.presence || 'EUR',
              amount: @amount.to_s
            }
          }
          
          # CROWDFUNDING: PAS de transfert automatique!
          # L'argent reste sur le compte plateforme jusqu'à validation admin
          # L'admin utilise CampaignSettlement pour transférer manuellement
          create_session_params[:payment_intent_data] = {
            transfer_group: "project_#{@project.id}",
            metadata: {
              project_id: @project.id.to_s,
              project_name: @project.name.to_s[0..99],
              project_permalink: @project.permalink.to_s,
              platform: determine_platform,
              project_owner_id: @project.user_id.to_s,
              project_owner_name: @project.user&.display_name.to_s[0..99],
              project_owner_email: @project.user&.email.to_s,
              contributor_id: current_user.id.to_s,
              contributor_name: current_user.display_name.to_s[0..99],
              contributor_email: current_user.email.to_s,
              contribution_id: @contribution&.id.to_s,
              currency: @project.currency.presence || 'EUR',
              amount: @amount.to_s,
              # Stocker l'ID du compte Connect pour transfert futur par admin
              destination_account: connect_ready_create ? @project.stripe_account_id : nil
            }
          }
          
          if connect_ready_create
            Rails.logger.info "Stripe CROWDFUNDING (create): Paiement sur compte plateforme (transfert manuel admin requis vers #{@project.stripe_account_id})"
          else
            Rails.logger.info "Stripe (create): Paiement direct - Compte Connect non prêt"
          end
          
          session = ::Stripe::Checkout::Session.create(create_session_params)
          
          redirect_to session.url, allow_other_host: true
        rescue ::Stripe::StripeError => e
          Rails.logger.error "Stripe payment error: #{e.message}"
          flash[:alert] = I18n.t('stripe.payment_error', error: e.message, default: "Erreur de paiement : #{e.message}")
          redirect_to "/projects/#{@project.permalink}"
        end
      end
      
      def success
        @project = ::Project.find(params[:project_id])
        session_id = params[:session_id]
        @contribution = nil
        @payment_confirmed = false
        
        if session_id
          begin
            session = ::Stripe::Checkout::Session.retrieve(session_id)
            
            if session.payment_status == 'paid'
              @payment_intent_id = session.payment_intent
              
              # Récupérer les métadonnées
              user_id = session.metadata['user_id']
              contribution_id = session.metadata['contribution_id']
              amount = session.amount_total / 100.0
              
              user = ::User.find_by(id: user_id)
              
              if user
                # Chercher ou créer la contribution
                if contribution_id.present?
                  @contribution = ::Contribution.find_by(id: contribution_id)
                end
                
                # Récupérer charge_id depuis PaymentIntent
                # CROWDFUNDING: Pas de transfert automatique - l'admin transfère manuellement
                charge_id = nil
                begin
                  payment_intent = ::Stripe::PaymentIntent.retrieve(session.payment_intent)
                  charge_id = payment_intent.latest_charge
                  Rails.logger.info "Stripe CROWDFUNDING: Paiement #{charge_id} reçu sur compte plateforme (transfert admin requis)"
                rescue ::Stripe::StripeError => e
                  Rails.logger.warn "Could not retrieve charge info: #{e.message}"
                end
                
                if @contribution
                  # Mise à jour de la contribution existante
                  @contribution.update(
                    payment_method: 'Stripe',
                    payment_id: session.payment_intent,
                    payment_service_fee: calculate_stripe_fee(amount),
                    stripe_charge_id: charge_id,
                    confirmed_at: Time.current,
                    # CROWDFUNDING: Pas de transfert automatique
                    stripe_transfer_id: nil,
                    stripe_transferred: false
                  )
                else
                  # Créer une nouvelle contribution
                  @contribution = ::Contribution.new(
                    project: @project,
                    user: user,
                    value: amount,
                    payment_method: 'Stripe',
                    payment_id: session.payment_intent,
                    payment_service_fee: calculate_stripe_fee(amount),
                    stripe_charge_id: charge_id,
                    confirmed_at: Time.current,
                    # CROWDFUNDING: Pas de transfert automatique
                    stripe_transfer_id: nil,
                    stripe_transferred: false
                  )
                  @contribution.save!
                end
                
                # Confirmer la contribution si pas déjà confirmée
                if @contribution.persisted? && @contribution.state != 'confirmed'
                  begin
                    @contribution.confirm!
                    @payment_confirmed = true
                    Rails.logger.info "Stripe: Contribution #{@contribution.id} confirmée pour le projet #{@project.name}"
                    
                    # Envoyer les notifications email
                    send_stripe_notifications(@contribution)
                  rescue => e
                    Rails.logger.warn "Could not confirm contribution: #{e.message}"
                    # La contribution est créée, même si la confirmation échoue
                    @payment_confirmed = false
                  end
                elsif @contribution.state == 'confirmed'
                  @payment_confirmed = true
                end
                
                # Créer l'ordre Stripe pour traçabilité
                create_stripe_order(session, @contribution, amount)
              end
              
              flash.now[:notice] = I18n.t('stripe.payment_success', default: 'Paiement réussi ! Merci pour votre contribution.')
            else
              flash.now[:alert] = I18n.t('stripe.payment_pending', default: 'Paiement en cours de traitement...')
            end
          rescue ::Stripe::StripeError => e
            Rails.logger.error "Error retrieving checkout session: #{e.message}"
            flash.now[:alert] = "Erreur lors de la vérification du paiement: #{e.message}"
          rescue => e
            Rails.logger.error "Error processing contribution: #{e.message}\n#{e.backtrace.join("\n")}"
            flash.now[:alert] = "Erreur lors de l'enregistrement de la contribution"
          end
        end
        
        render :success
      end
      
      def cancel
        @project = ::Project.find(params[:project_id])
        flash[:alert] = I18n.t('stripe.payment_cancelled', default: 'Paiement annulé')
        redirect_to "/projects/#{@project.permalink}"
      end
      
      private
      
      def calculate_stripe_fee(amount)
        # Frais Stripe: 1.4% + 0.25€ pour les cartes européennes
        (amount * 0.014 + 0.25).round(2)
      end
      
      def account_ready_for_transfers?(account)
        account.payouts_enabled &&
          stripe_value(account.capabilities, :transfers) == 'active' &&
          account_requirements_due(account).empty?
      end

      def account_requirements_due(account)
        requirements = account.requirements
        (
          Array(stripe_value(requirements, :currently_due)) +
          Array(stripe_value(requirements, :past_due))
        ).uniq
      end

      def stripe_value(object, key)
        return nil unless object
        return object[key] if object.respond_to?(:[]) && object[key].present?
        return object[key.to_s] if object.respond_to?(:[]) && object[key.to_s].present?
        return object.public_send(key) if object.respond_to?(key)

        nil
      end

      def create_stripe_order(session, contribution, amount)
        return unless contribution
        
        begin
          if defined?(Neighborly::Stripe::Order) && Neighborly::Stripe::Order.table_exists?
            Neighborly::Stripe::Order.find_or_create_by(
              stripe_checkout_session_id: session.id
            ) do |order|
              order.user = contribution.user
              order.project = @project
              order.contribution = contribution
              order.stripe_payment_intent_id = session.payment_intent
              order.amount_cents = (amount * 100).to_i
              order.currency = session.currency || 'eur'
              order.status = 'completed'
            end
          end
        rescue => e
          Rails.logger.warn "Could not create Stripe order: #{e.message}"
        end
      end
      
      def send_stripe_notifications(contribution)
        return unless contribution&.persisted?
        
        begin
          # Notification au contributeur
          contribution.notify_owner(
            :stripe_payment_confirmed,
            {},
            { project: contribution.project, bcc: Configuration[:email_payments] }
          )
          Rails.logger.info "Stripe: Email de confirmation envoyé au contributeur #{contribution.user.email}"
          
          # Notification au porteur de projet
          contribution.project.notify_owner(:project_owner_contribution_confirmed)
          Rails.logger.info "Stripe: Email de notification envoyé au porteur de projet #{contribution.project.user.email}"
        rescue => e
          Rails.logger.error "Stripe: Erreur envoi notifications: #{e.message}"
        end
      end
      
      # Détermine la plateforme (Fiatope ou Kwendoo) basé sur le domaine
      # Permet de filtrer dans Stripe: metadata:platform=fiatope ou metadata:platform=kwendoo
      def determine_platform
        host = request.host.to_s.downcase rescue ''
        if host.include?('kwendoo')
          'kwendoo'
        elsif host.include?('fiatope')
          'fiatope'
        else
          # Fallback basé sur le partenaire du projet si disponible
          if @project&.respond_to?(:partner) && @project.partner&.name.to_s.downcase.include?('kwendoo')
            'kwendoo'
          else
            'fiatope'
          end
        end
      end
    end
  end
end
