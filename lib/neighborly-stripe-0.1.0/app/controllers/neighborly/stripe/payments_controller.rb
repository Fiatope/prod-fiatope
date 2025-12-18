module Neighborly
  module Stripe
    class PaymentsController < ApplicationController
      before_action :authenticate_user!, except: [:success, :cancel]
      
      def new
        @project = ::Project.find(params[:project_id])
        @contribution = @project.contributions.find(params[:contribution_id]) if params[:contribution_id].present?
        @amount = @contribution&.value || params[:amount]&.to_f || 10.0
        
        unless @project.use_stripe?
          render html: "<div class='alert alert-warning'>#{I18n.t('stripe.project_not_ready', default: 'Ce projet ne peut pas encore accepter les paiements Stripe')}</div>".html_safe
          return
        end
        
        # Rendre la vue avec le formulaire de paiement
        render :new, layout: false
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
          flash[:alert] = I18n.t('stripe.project_not_ready', default: 'Ce projet ne peut pas encore accepter les paiements Stripe')
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
              connect_ready_create = account.charges_enabled && account.capabilities&.transfers == 'active'
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
              project_id: @project.id,
              user_id: current_user.id,
              contribution_id: @contribution&.id,
              platform: 'fiatope'
            }
          }
          
          # Ajouter transfer_data seulement si Connect est prêt
          if connect_ready_create
            create_session_params[:payment_intent_data] = {
              application_fee_amount: platform_fee,
              transfer_data: {
                destination: @project.stripe_account_id
              },
              metadata: {
                project_id: @project.id,
                project_name: @project.name,
                user_id: current_user.id,
                user_email: current_user.email
              }
            }
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
                
                if @contribution
                  # Mise à jour de la contribution existante
                  @contribution.update(
                    payment_method: 'Stripe',
                    payment_id: session.payment_intent,
                    payment_service_fee: calculate_stripe_fee(amount),
                    confirmed_at: Time.current
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
                    confirmed_at: Time.current
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
    end
  end
end
