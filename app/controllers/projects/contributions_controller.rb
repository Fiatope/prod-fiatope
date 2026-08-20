class Projects::ContributionsController < ApplicationController
  after_action :verify_authorized, except: :index
  skip_before_action :set_persistent_warning
  # Renommé: vérification des pré-requis utilisateur (indépendant de MangoPay)
  before_action :has_user_prerequisites, only: [:new, :create]
  skip_before_action :verify_authenticity_token, only: [:orange_money_payment_confirmation, :pay_plus_africa_payment_confirmation, :touch_payment_initialization, :touch_payment_status, :touch_payment_return, :mollie_webhook]
  skip_after_action :verify_authorized, only: [:cancel, :orange_money_payment_confirmation, :pay_plus_africa_payment_confirmation, :touch_payment_initialization, :touch_payment_status, :touch_payment_return, :touch_payment_pending, :touch_payment_check_status, :mollie_payment_new, :mollie_payment_return, :mollie_webhook]

  has_scope :available_to_count, type: :boolean
  has_scope :with_state
  has_scope :page, default: 1

  def index
    @project        = parent
    @contributions  = collection
    @active_matches = parent.matches.active
    if request.xhr? && params[:page] && params[:page].to_i > 1
      render collection
    end
  end

  def edit
    @project      = parent
    @contribution = resource
    authorize resource
    
    # Self-healing: when the user lands back on /edit after paying, check
    # whether a payment provider has already notified us successfully
    # (transaction row has a txnid / reference set by their webhook).
    # If so, promote the contribution to :confirmed here. Catches the rare
    # cases where the async webhook was received but its state transition
    # rolled back (generate_tickets exception, transient DB error, etc.)
    # — without this, the user sees the payment form again forever.
    unless @contribution.state == "confirmed" || @contribution.state == "canceled"
      reconcile_provider_payment(@contribution)
    end
    
    if @contribution.state == "canceled"
      flash.notice = "This order has been canceled. Please create a new one!"
      redirect_to project_path(@project)
    elsif @contribution.state == "confirmed"
      flash.notice = t('controllers.projects.contributions.create.success')
      redirect_to project_contribution_path(@project, @contribution)
    end
  end

  def mailing
    # @_policy_authorized = true if current_user.admin
    authorize resource if current_user.admin
    @contribution = resource
    if params[:tips] 
      NotificationsMailer.tips(@contribution).deliver if params[:tips]
      flash.notice = 'Mail correctement envoyé'
      redirect_back(fallback_location: root_path)
    end
  end

  def show
    @project      = parent
    @contribution = resource
    authorize resource
    if @contribution.state == "confirmed"
      flash.notice = t('controllers.projects.contributions.create.success')
    elsif @contribution.state == "canceled"
      flash.notice = t('controllers.projects.contributions.show.canceled_notice', default: 'This contribution has been canceled. Please create a new one!')
      redirect_to project_path(@project) and return
    end
  end

  def new
    @project      = parent
    @contribution = ContributionForm.new(project: parent, user: current_user)
    authorize @contribution
   
    if @project.presale?
      @rewards = @project.rewards.not_soon.order(:minimum_value)
    else
      @rewards = [empty_reward] + @project.rewards.not_soon.remaining.order(:minimum_value)
    end

    if params[:reward_id] && (selected_reward = @project.rewards.not_soon.find(params[:reward_id])) && !selected_reward.sold_out?
      @contribution.reward = selected_reward
      @contribution.value = "%0.0f" % selected_reward.minimum_value
    end
  end

  def create
    @project      = parent
    
    # Gérer la conversion de devise si l'utilisateur a saisi en FCFA
    contribution_params = permitted_params[:contribution_form].dup
    fcfa_amount = nil
    
    if params[:selected_currency] == 'FCFA' && contribution_params[:value].present?
      conversion_rate = ENV['CFA_CONVERSION_RATE']&.to_f || 656.0
      fcfa_amount = contribution_params[:value].to_f.round(2)  # Sauvegarder le montant FCFA exact
      contribution_params[:value] = (fcfa_amount / conversion_rate).round(2)
      Rails.logger.warn "[Contribution] User entered FCFA #{fcfa_amount}, converted to EUR #{contribution_params[:value]} (rate: #{conversion_rate})"
    end
    
    @contribution = ContributionForm.new(contribution_params.merge(user: current_user, project: parent))
    
    # Si l'utilisateur a saisi en FCFA, utiliser directement ce montant pour cfa_value
    if fcfa_amount
      @contribution.define_singleton_method(:cfa_value_from_user_input) { fcfa_amount }
    end
    rewards = permitted_params[:reward_ids]
    if @project.presale? && permitted_params[:user_articles]
      permitted_user_articles = permitted_params[:user_articles].to_unsafe_h
      user_articles = []

      permitted_user_articles.each_value do |permitted_user_article|
         user_article = permitted_user_article.shift
         user_articles << user_article[1].split(",").join(", ")
      end

      articleSelected = []
      user_articles.each_with_index do |article|
        articleSelected << Article.find(article)
      end

      @contribution.articles = articleSelected
    end
    
    if(rewards.present?)
      if @project.presale?
        value = 0
        rewards['id'].each_with_index do |r, index|
          price = Reward.find(r).minimum_value
          qty = rewards['quantity'][index]
          if price && qty
            value +=  "#{price}".to_i * qty.to_i 
          end
          @contribution.value = value
        end
      end
    end

    
    
    
    authorize @contribution

    if @contribution.save
      if @project.presale?
        rewards['id'].each_with_index do |r, index|
           ContributionReward.create(contribution_id: @contribution.id, reward_id: r, quantity: rewards['quantity'][index])
        end
      end
      puts "zaeaze #{rewards}"
     
      if( !@project.presale? && rewards.present? && !rewards['id'].nil? && rewards['id'][0] != "on")
        ContributionReward.create(contribution_id: @contribution.id, reward_id: rewards['id'][0], quantity: 1)
      end
      
      session[:thank_you_contribution_id] = @contribution.id
      flash.delete(:notice)
      redirect_to edit_project_contribution_path(project_id: @project, id: @contribution.id)
    else
      flash.alert = t('controllers.projects.contributions.create.error')
      redirect_to new_project_contribution_path(@project)
    end
    
  end

  def cancel
    if resource.user == current_user
      @contribution = resource
      @contribution.orange_money_transactions.update_all(status_string: "CANCELLED")
      response_message = t('controllers.projects.contributions.cancel.error')
      @contribution.update(
        response_code: "CANCELLED",
        transaction_number: @contribution.orange_money_transactions.where("txnid is not null").last.try(:txnid),
        response_message: response_message,
        payment_method: "Orange Money"
      )
      @contribution.state_event = :cancel
      @contribution.save!
      redirect_to edit_project_contribution_path(@contribution.project, @contribution), alert: response_message
    else
      redirect_to root_path, alert: "You are not authorized to cancel this contribution"
    end
  end



  def credits_checkout
    @contribution = resource
    authorize resource
    if current_user.credits < @contribution.value
      flash.alert = t('controllers.projects.contributions.credits_checkout.no_credits')
      return redirect_to new_project_contribution_path(@contribution.project)
    end

    unless @contribution.confirmed?
      @contribution.update({ payment_method: 'Credits' })
      @contribution.confirm!
    end

    flash.notice = t('controllers.projects.contributions.credits_checkout.success')
    redirect_to project_contribution_path(parent, resource)
  end


  def orange_money_payment_initialization
    @contribution = resource
    authorize @contribution

    transaction = OrangeMoneyService.initialize_payment_for(@contribution, country: params[:country])
    if transaction.status_string == "OK"
      Rails.logger.warn "[OrangeMoney] SUCCESS → redirecting to #{transaction.payment_url}"
      redirect_to transaction.payment_url
    else
      Rails.logger.warn "[OrangeMoney] FAILED status_string=#{transaction.status_string.inspect} for contribution##{@contribution.id} project##{@contribution.project.id} requested_country=#{params[:country].inspect} address_state=#{@contribution.project.address_state.inspect}"
      redirect_to edit_project_contribution_path(@contribution.project, @contribution), alert: "Orange Money is temporarily unavailable. Please pick another payment method (#{transaction.status_string})"
    end
  end


  def pay_plus_africa_payment_initialization
    @contribution = resource
    authorize @contribution

    transaction = PayPlusAfricaService.initialize_payment_for(@contribution)

    # abort transaction.status_string

    if transaction.status_string == "00"
      @payment_url = transaction.payment_url

      respond_to do |format|
        format.js {render layout: false}
      end
    else
      redirect_to edit_project_contribution_path(@contribution.project, @contribution), alert: "Payplus Africa is temporarily unavailable. Please pick another payment method (#{transaction.status_string})"
    end
  end


  def orange_money_payment_confirmation
    if params["status"] == "SUCCESS"
      transaction = OrangeMoneyTransaction.find_by(notif_token: params["notif_token"])
      transaction.update_column(:txnid, params["txnid"])
      @contribution = Contribution.find_by(id: transaction.contribution_id)
      if params["status"] == "SUCCESS"
        response_message = t('controllers.projects.contributions.orange_money_payment_confirmation.success')
      else
        response_message = t('controllers.projects.contributions.orange_money_payment_initialization.error', status: params["status"])
      end
      @contribution.response_code = params["status"]
      @contribution.transaction_number = params["txnid"]
      @contribution.response_message = response_message
      @contribution.payment_method = "Orange Money"
      @contribution.state_event = params["status"] == "SUCCESS" ? :confirm : :cancel
      @contribution.save!
      @contribution.notify_owner(:orange_money_payment_confirmed) if params["status"] == "SUCCESS"
    end
    render json: { success: true }
  end


  def touch_payment_new
    @contribution = resource
    authorize @contribution

    @project = @contribution.project

    @html_operators = ''
    @operators = TouchService::LIST_OPERATORS
    @operators.each do |country, operators|
      @html_operators += '<optgroup label="' + country + '">'
      operators.each do |key, operator|
        @html_operators += '<option value="' + key + '">' + operator + '</option>'
      end
      @html_operators += '</optgroup>'
    end
  end


  def touch_payment_initialization
    @contribution = Contribution.find_by!(id: touch_params[:id])
    authorize @contribution

    @project = @contribution.project

    country_operator = (touch_params[:country_operator] || '').split('_')
    country  = country_operator[0]
    operator = country_operator[1]
    phone    = clean_touch_phone(touch_params[:phone], country)
    @new_payment = false

    if country.blank? || operator.blank?
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution), notice: "Veuillez sélectionner un opérateur"
      return
    end

    if phone.blank?
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution), notice: "Veuillez entrer votre numéro de téléphone"
      return
    end

    phone_error = validate_touch_phone(phone, country)
    if phone_error
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution), notice: phone_error
      return
    end

    payment = TouchService.new country, operator, phone, @contribution
    @response = payment.initiate_paiement

    @response.merge!({
      "country_operator" => touch_params[:country_operator]
    })

    qr_present = TouchService.qr_code_from(@response).present?
    Rails.logger.info("[ContributionsController#touch_payment_initialization] contribution_id=#{@contribution.id} status=#{@response['status']} id_from_client_present=#{@response['idFromClient'].present?} qr_present=#{qr_present} om_present=#{@response['OM'].present?} maxit_present=#{@response['MAXIT'].present?} validity=#{@response['validity']} response_keys=#{@response.keys.inspect}")

    if @response['status'] == 'INITIATED' && @response['idFromClient'].present?
      unless qr_present || @response['OM'].present? || @response['MAXIT'].present?
        Rails.logger.warn("[ContributionsController#touch_payment_initialization] INITIATED without any QR/OM/MAXIT link — contribution_id=#{@contribution.id} response_keys=#{@response.keys.inspect}")
      end
      if @contribution.canceled?
        @contribution.pendent
        Rails.logger.info("[ContributionsController#touch_payment_initialization] contribution #{@contribution.id} reset from canceled to pending for new payment attempt")
      end
      render 'projects/contributions/touch_payment_initialization'
    else
      @response['message'] ||= @response['detailMessage']
      @response['message'] ||= @response['description']
      @response['status'] ||= @response['code']
      Rails.logger.error("[ContributionsController#touch_payment_initialization] payment failed code=#{@response['status']} message=#{@response['message']}")
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution), notice: "Le paiement n'a pas pu être initié. Veuillez vérifier votre numéro et réessayer, ou utiliser un autre moyen de paiement."
    end
  end


  def touch_payment_status
    @contribution = Contribution.find_by!(id: touch_params[:id])
    authorize @contribution

    @project = @contribution.project

    country_operator = (touch_params[:country_operator] || '').split('_')
    country  = country_operator[0]
    operator = country_operator[1]
    id_client = touch_params[:id_client]
    commit = touch_params[:commit]
    @new_payment = false

    if country.blank? || operator.blank?
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution), notice: "Veuillez sélectionner un opérateur"
      return
    end

    if commit == 'Terminer le paiement'
      @new_payment = true
      payment = TouchService.new country, operator
      @response = payment.check_status id_client

      @response.merge!({
        "country_operator" => touch_params[:country_operator],
        "idFromClient" => id_client
      })

      Rails.logger.debug("[TouchService] check_status response: #{@response}")

      if @response['status'] == 'PENDING'
        flash.now[:notice] = 'Valider le paiement sur votre téléphone'
        render 'projects/contributions/touch_payment_initialization'
      elsif @response['status'] == 'SUCCESSFUL'
        # Check_status confirmed success
        begin
          unless @contribution.confirmed?
            @contribution.response_code = @response['status']
            @contribution.payment_id = @response['idFromClient']
            @contribution.response_message = t('controllers.projects.contributions.create.success')
            @contribution.payment_method = 'Touch'
            @contribution.state_event = :confirm
            @contribution.save!
          end
        rescue => e
          Rails.logger.error("[TouchService] touch_payment_status confirm error: #{e.class} #{e.message}")
          # Contribution may have been confirmed by callback during this request
          @contribution.reload
        end
        flash.notice = t('controllers.projects.contributions.create.success')
        redirect_to project_contribution_path(project_id: @contribution.project, id: @contribution.id)
      elsif @contribution.confirmed?
        # Already confirmed by callback — check_status may have returned an error but payment succeeded
        flash.notice = t('controllers.projects.contributions.create.success')
        redirect_to project_contribution_path(project_id: @contribution.project, id: @contribution.id)
      else
        # check_status returned an error code (401, CONFIG_ERROR, etc.)
        # Do NOT cancel — payment may still be processing or confirmed via callback
        # Redirect to pending/edit page so user can wait for callback
        Rails.logger.warn("[TouchService] check_status returned #{@response['status']} for #{id_client} — not canceling, waiting for callback")
        redirect_to touch_payment_pending_project_contribution_path(@contribution.project, @contribution)
      end
    else
      redirect_to touch_payment_new_project_contribution_path(@contribution.project, @contribution)
    end
  end


  def touch_payment_pending
    @contribution = Contribution.find_by!(id: touch_params[:id])
    authorize @contribution
    @project = @contribution.project

    if @contribution.confirmed?
      flash.notice = t('controllers.projects.contributions.create.success')
      redirect_to project_contribution_path(project_id: @project, id: @contribution)
    elsif @contribution.canceled?
      flash.alert = t('controllers.projects.contributions.touch_payment.canceled')
      redirect_to edit_project_contribution_path(project_id: @project, id: @contribution)
    end
  end

  def touch_payment_check_status
    @contribution = Contribution.find_by!(id: touch_params[:id])
    authorize @contribution

    render json: {
      confirmed: @contribution.confirmed?,
      canceled:  @contribution.canceled?,
      state:     @contribution.state
    }
  rescue Pundit::NotAuthorizedError
    render json: { confirmed: false, canceled: false, state: 'unauthorized' }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { confirmed: false, canceled: false, state: 'not_found' }, status: :ok
  end

  def touch_payment_return
    @contribution = Contribution.find_by!(id: params[:id] || touch_params[:id])
    @project = @contribution.project

    # Handle Touch API callback notification
    payment_status = params[:status]
    partner_transaction_id = params[:partner_transaction_id]

    if payment_status.present? && partner_transaction_id.present?
      begin
        if payment_status == 'SUCCESSFUL'
          unless @contribution.confirmed?
            @contribution.response_code    = payment_status
            @contribution.payment_id       = partner_transaction_id
            @contribution.response_message = t('controllers.projects.contributions.create.success')
            @contribution.payment_method   = 'Touch'
            @contribution.state_event      = :confirm
            @contribution.save!
            Rails.logger.info("[TouchService] Payment confirmed via callback: #{partner_transaction_id}")
          else
            Rails.logger.info("[TouchService] Callback received but contribution #{@contribution.id} already confirmed — skipping")
          end
        else
          unless @contribution.canceled? || @contribution.confirmed?
            @contribution.response_code    = payment_status
            @contribution.payment_id       = partner_transaction_id
            @contribution.response_message = "Payment #{payment_status.downcase}"
            @contribution.payment_method   = 'Touch'
            @contribution.state_event      = :cancel
            @contribution.save!
            Rails.logger.info("[TouchService] Payment #{payment_status.downcase} via callback: #{partner_transaction_id}")
          else
            Rails.logger.info("[TouchService] Callback #{payment_status} received but contribution #{@contribution.id} already in terminal state — skipping")
          end
        end
      rescue => e
        Rails.logger.error("[TouchService] callback processing error for contribution #{@contribution.id}: #{e.class} #{e.message}")
        # Still return 200 to prevent Touchpay from retrying indefinitely
        head :ok and return
      end

      # Return HTTP 200 for API acknowledgment (no HTML response needed)
      head :ok and return
    end

    # For user browser redirect (if accessed directly)
    if @contribution.confirmed?
      flash.notice = t('controllers.projects.contributions.create.success')
      redirect_to project_contribution_path(project_id: @project, id: @contribution)
    else
      redirect_to edit_project_contribution_path(project_id: @project, id: @contribution)
    end
  end


  def pay_plus_africa_payment_confirmation
    transaction = payplus_transaction_from_callback

    unless transaction
      Rails.logger.warn "[PayPlus Callback] Transaction introuvable — payload: #{request.raw_post.to_s.truncate(500)}"
      return head :not_found
    end

    @contribution = Contribution.find_by(id: transaction.contribution_id)
    return head :not_found unless @contribution

    # Idempotence : PayPlus envoie 2 notifications par événement (form + json)
    if @contribution.state == "confirmed" || @contribution.state == "canceled"
      return payplus_callback_response(@contribution.state == "confirmed" ? :confirmed : :canceled)
    end

    # Toujours re-vérifier auprès de l'API PayPlus (ne jamais faire confiance au payload seul)
    response_status = PayPlusAfricaService.confirm_payment_for(@contribution, transaction)
    Rails.logger.info "[PayPlus Callback] contrib=#{@contribution.id} confirm=#{response_status.inspect}"

    if response_status["response_code"] == "00"
      case response_status["status"]
      when "completed"
        transaction.update_column(:invoice_number, response_status["token"]) if response_status["token"].present?
        @contribution.response_code = "00"
        @contribution.transaction_number = transaction.invoice_number.presence || transaction.notif_token
        @contribution.response_message = t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.success')
        @contribution.payment_method = "Pay Plus Africa"
        @contribution.state_event = :confirm
        @contribution.save!
        payplus_callback_response(:confirmed)
      when "pending"
        # Paiement pas encore finalisé : ne rien faire, PayPlus notifiera à nouveau
        payplus_callback_response(:pending)
      else
        @contribution.response_code = response_status["status"].to_s
        @contribution.response_message = t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.error', status: response_status["status"])
        @contribution.payment_method = "Pay Plus Africa"
        @contribution.state_event = :cancel
        @contribution.save!
        payplus_callback_response(:canceled)
      end
    else
      Rails.logger.error "[PayPlus Callback] Confirm API error contrib=#{@contribution.id}: #{response_status.inspect}"
      head :ok
    end
  rescue => e
    Rails.logger.error "[PayPlus Callback] #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    head :internal_server_error
  end


  protected

  TOUCH_COUNTRY_CODES = { 'SN' => '221', 'CM' => '237', 'CI' => '225', 'GN' => '224' }.freeze
  TOUCH_PHONE_LENGTHS = { 'SN' => 9, 'CM' => 9, 'GN' => 9, 'CI' => 10 }.freeze

  def clean_touch_phone(phone, country)
    return '' if phone.blank?
    digits = phone.to_s.gsub(/[^0-9]/, '')
    cc = TOUCH_COUNTRY_CODES[country.to_s.upcase]
    if cc.present?
      digits = digits.sub(/\A00#{Regexp.escape(cc)}/, '')
      digits = digits.sub(/\A#{Regexp.escape(cc)}/, '') if digits.length > (TOUCH_PHONE_LENGTHS[country.to_s.upcase] || 9)
    end
    digits
  end

  def validate_touch_phone(phone, country)
    expected = TOUCH_PHONE_LENGTHS[country.to_s.upcase]
    if expected && phone.length != expected
      "Numéro de téléphone invalide (#{expected} chiffres requis, sans indicatif pays). Exemple pour le Sénégal: 771234567"
    elsif phone.length < 7 || phone.length > 12
      "Numéro de téléphone invalide (#{phone.length} chiffres). Entrez uniquement les chiffres sans indicatif pays."
    end
  end

  def touch_params
    params.permit(:id, :phone, :country_operator, :id_client, :commit)
  end

  def permitted_params
    params.permit(policy(@contribution || ContributionForm).permitted_attributes)
  end

  def collection
    @contributions ||= apply_scopes(parent.contributions).available_to_display.where(matching_id: nil).order("confirmed_at DESC").per(10)
  end

  def empty_reward
    Reward.new(minimum_value: 0, description: t('controllers.projects.contributions.new.no_reward'))
  end

  def parent
    @parent ||= Project.find_by_permalink!(params[:project_id])
  end

  def resource
    @resource ||= parent.contributions.find(params[:id])
  end

  private

  # Vérifie que l'utilisateur a complété son profil de base
  # (nom, prénom, date de naissance, etc.) - indépendant du système de paiement
  def has_user_prerequisites
    if user_signed_in?
      if current_user.light_authentication_ready?
        return true
      else
        # Message générique, pas spécifique à MangoPay
        flash.alert = t('projects.contributions.new.profile_incomplete', 
                        default: 'Veuillez compléter votre profil avant de contribuer.')
        redirect_to edit_user_path(current_user, redirect_url: new_project_contribution_path(parent.permalink)) and return false
      end
    else
      redirect_to new_user_registration_path(:from_contribution => parent)
    end
  end
  
  # Réconcilie automatiquement les paiements confirmés par webhook
  # Appelé quand l'utilisateur revient sur /edit après avoir payé
  def reconcile_provider_payment(contribution)
    # Vérifier Orange Money
    om_tx = contribution.orange_money_transactions.where.not(txnid: [nil, ""]).order(:id).last
    if om_tx
      Rails.logger.info "[reconcile contrib=#{contribution.id}] Orange Money txnid=#{om_tx.txnid} → confirm"
      contribution.response_code = "SUCCESS"
      contribution.transaction_number = om_tx.txnid
      contribution.response_message ||= t('controllers.projects.contributions.orange_money_payment_confirmation.success')
      contribution.payment_method ||= "Orange Money"
      contribution.state_event = :confirm
      contribution.save!
      return true
    end
    
    # Vérifier Pay Plus Africa - transaction déjà confirmée par webhook
    ppa_tx = contribution.pay_plus_africa_transactions.where.not(invoice_number: [nil, ""]).order(:id).last
    if ppa_tx
      Rails.logger.info "[reconcile contrib=#{contribution.id}] PayPlusAfrica invoice=#{ppa_tx.invoice_number} → confirm"
      contribution.response_code = "00"
      contribution.transaction_number = ppa_tx.invoice_number
      contribution.response_message ||= t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.success')
      contribution.payment_method ||= "Pay Plus Africa"
      contribution.state_event = :confirm
      contribution.save!
      return true
    end
    
    # Si pas de invoice_number, vérifier activement auprès de PayPlus
    ppa_tx_pending = contribution.pay_plus_africa_transactions.where(invoice_number: [nil, ""]).order(:id).last
    if ppa_tx_pending && ppa_tx_pending.notif_token.present?
      Rails.logger.info "[reconcile contrib=#{contribution.id}] Checking PayPlus status for token=#{ppa_tx_pending.notif_token}"
      begin
        response_status = PayPlusAfricaService.confirm_payment_for(contribution, ppa_tx_pending)
        if response_status["response_code"] == "00" && response_status["status"] == "completed"
          Rails.logger.info "[reconcile contrib=#{contribution.id}] PayPlus confirmed! token=#{response_status['token']}"
          ppa_tx_pending.update_column(:invoice_number, response_status["token"])
          contribution.response_code = "00"
          contribution.transaction_number = response_status["token"]
          contribution.response_message = t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.success')
          contribution.payment_method = "Pay Plus Africa"
          contribution.state_event = :confirm
          contribution.save!
          return true
        end
      rescue => e
        Rails.logger.error "[reconcile contrib=#{contribution.id}] PayPlus check failed: #{e.message}"
      end
    end
    
    false
  rescue => e
    Rails.logger.error "[reconcile contrib=#{contribution.id}] failed: #{e.class} #{e.message}"
    false
  end

  # Identifie la transaction PayPlus depuis le callback :
  # - via params["token"] (anciens callbacks PayPlus)
  # - sinon via custom_data.return_data = "projectId-contributionId"
  def payplus_transaction_from_callback
    token = params["token"].presence
    return PayPlusAfricaTransaction.find_by(notif_token: token) if token

    entries = params["custom_data"]
    entries = entries.values if entries.is_a?(Hash) || entries.is_a?(ActionController::Parameters)
    Array(entries).each do |entry|
      key   = (entry["keyof_customdata"] rescue nil)
      value = (entry["valueof_customdata"] rescue nil)
      next unless key == "return_data" && value.present?
      _project_id, contribution_id = value.to_s.split("-")
      next if contribution_id.blank?
      return PayPlusAfricaTransaction.where(contribution_id: contribution_id)
                                     .where.not(notif_token: [nil, ""])
                                     .order(:id).last
    end
    nil
  end

  # Réponse du callback : 200 OK pour le serveur PayPlus (POST),
  # redirection avec message pour le navigateur (GET legacy)
  def payplus_callback_response(outcome)
    if request.get?
      case outcome
      when :confirmed
        redirect_to project_path(@contribution.project), notice: t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.success')
      when :pending
        redirect_to edit_project_contribution_path(@contribution.project, @contribution), notice: t('controllers.projects.contributions.pay_plus_africa_payment_confirmation.pending', default: 'Paiement en cours de traitement...')
      else
        redirect_to edit_project_contribution_path(@contribution.project, @contribution), alert: @contribution.response_message
      end
    else
      head :ok
    end
  end

  public

  # ========== MOLLIE PAYMENT METHODS ==========

  def mollie_payment_new
    @contribution = Contribution.find(params[:id])
    @project = @contribution.project

    service = MollieService.new(@contribution)
    result = service.create_payment

    if result[:success]
      @contribution.update_column(:payment_id, result[:payment_id])
      Rails.logger.info "[Mollie] Redirecting to checkout: payment_id=#{result[:payment_id]} contribution_id=#{@contribution.id}"
      redirect_to result[:checkout_url], allow_other_host: true
    else
      flash.alert = "Erreur Mollie: #{result[:error]}"
      redirect_to edit_project_contribution_path(@project, @contribution)
    end
  end

  def mollie_payment_return
    @contribution = Contribution.find(params[:id])
    @project = @contribution.project

    # L'utilisateur revient après paiement
    # On attend le webhook pour confirmer, mais on peut vérifier le statut
    if @contribution.payment_id.present?
      payment_status = MollieService.check_payment_status(@contribution.payment_id)
      
      if payment_status && payment_status[:paid]
        # Paiement confirmé
        flash.notice = t('controllers.projects.contributions.create.success')
        redirect_to project_contribution_path(@project, @contribution)
      else
        # En attente de confirmation
        flash.notice = "Paiement en cours de traitement..."
        redirect_to edit_project_contribution_path(@project, @contribution)
      end
    else
      redirect_to edit_project_contribution_path(@project, @contribution)
    end
  end

  def mollie_webhook
    payment_id = params[:id]
    
    Rails.logger.info "[Mollie Webhook] Received for payment_id=#{payment_id}"

    payment = MollieService.get_payment(payment_id)
    
    unless payment
      Rails.logger.error "[Mollie Webhook] Payment not found: #{payment_id}"
      head :not_found
      return
    end

    contribution = Contribution.find_by(payment_id: payment_id)
    
    unless contribution
      Rails.logger.error "[Mollie Webhook] Contribution not found for payment_id=#{payment_id}"
      head :not_found
      return
    end

    Rails.logger.info "[Mollie Webhook] Processing: payment_id=#{payment_id} status=#{payment.status} contribution_id=#{contribution.id}"

    if payment.paid?
      # Paiement réussi
      contribution.update(
        transaction_number: payment.id,
        response_message: t('controllers.projects.contributions.create.success'),
        payment_method: 'Mollie'
      )
      contribution.state_event = :confirm
      contribution.save!
      
      Rails.logger.info "[Mollie Webhook] Payment confirmed: contribution_id=#{contribution.id}"
    elsif payment.failed? || payment.canceled? || payment.expired?
      # Paiement échoué
      contribution.update(
        response_message: "Paiement #{payment.status}",
        payment_method: 'Mollie'
      )
      contribution.state_event = :cancel
      contribution.save!
      
      Rails.logger.warn "[Mollie Webhook] Payment failed: contribution_id=#{contribution.id} status=#{payment.status}"
    end

    head :ok
  rescue => e
    Rails.logger.error "[Mollie Webhook] Error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    head :internal_server_error
  end
end
