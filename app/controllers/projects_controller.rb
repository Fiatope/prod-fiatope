# coding: utf-8
class ProjectsController < ApplicationController
  after_action :verify_authorized, except: [:index, :video, :video_embed, :embed,
                                            :embed_panel, :comments, :budget, :english,
                                            :reward_contact, :send_reward_email,
                                            :start, :coaching, :crowdfunding, :consulting, :change_recommended,
                                            :request_payout]

  before_action :has_prerequisites, only: [:new, :create]

  respond_to :html


  def new
    @project = Project.new(user: current_user)
    authorize @project
  end

  def index
    projects_vars = {
      coming_soon: :soon,
      ending_soon: :expiring,
      featured:    :featured,
      recommended: :recommends,
      successful:  :successful
    }

    projects_vars.each do |var_name, scope|
      instance_variable_set "@#{var_name}", ProjectsForHome.send(scope)
    end


    @montant_total_collecte = Contribution.joins(:project).where('contributions.state' => 'confirmed').sum('contributions.value').to_i

    @total_contributeurs = Contribution.joins(:user).where('contributions.state' => 'confirmed').select('users.id').distinct.count

    # @total_projects_accompagnes = Contribution.joins(:project).where('contributions.state' => 'confirmed').where("projects.expires_at < current_timestamp").select('projects.id').count

    #@total_projects_accompagnes = Project.expired.count
    
    @total_projects_accompagnes = Project.successful.count


    @total_pays = Contribution.joins(:project).where('contributions.state' => 'confirmed').select('projects.address_state').distinct.count



    @recommended = Project.recommended.first(3)

    @projects_to_show_on_home_page = Project.projects_to_show_on_home_page
    
    @successful = @successful.take(2) if browser.device.mobile?
    @channels = Channel.with_state('online').order('RANDOM()').limit(4)
    @press_assets = PressAsset.order('created_at DESC').limit(5)

    if params[:partner_id]
      @partner = Partner.find_by_permalink(params[:partner_id])
      render layout: 'application_partner' and return
    end
  end

  def create
    @project = Project.new(permitted_params[:project].merge(user: current_user))
    @project.address_state = @project.address_state.capitalize
    authorize @project
    @project.save
    respond_with @project, location: success_project_path(@project)
  end

  def success
    authorize resource
  end

  def edit
    authorize resource
    respond_with resource
    # redirect_to project_path(@project)
  end

  def update
    authorize resource
    old_hero = resource.read_attribute(:hero_image)
    old_uploaded = resource.read_attribute(:uploaded_image)
    updated_project = Project.update(resource.id, permitted_params[:project].merge!(address_state: resource.address_state.to_s.capitalize))
    if updated_project.errors.any?
      Rails.logger.warn "[ProjectUpdate] FAILED for project ##{resource.id} (#{resource.permalink}): #{updated_project.errors.full_messages.join(', ')}"
    else
      new_hero = updated_project.read_attribute(:hero_image)
      new_uploaded = updated_project.read_attribute(:uploaded_image)
      Rails.logger.info "[ProjectUpdate] OK ##{resource.id} hero_image: '#{old_hero}' → '#{new_hero}' | uploaded_image: '#{old_uploaded}' → '#{new_uploaded}'"
    end
    respond_with(updated_project, location: project_path(@project))
  end

  def change_recommended
    @project = resource
    if @project.recommended
      @project.recommended = false
    else
      @project.recommended = true
    end
    redirect_back(fallback_location: root_path) if @project.save
  end

  def show
    authorize resource
    set_facebook_url_admin(resource.user)
    render :about if request.xhr?

    @project = resource

    # Précalculer le statut Stripe du porteur pour éviter les appels API dans la vue
    # Ne vérifier que si l'utilisateur connecté est le porteur du projet
    @stripe_onboarding_complete = user_signed_in? && current_user == @project.user &&
                                   current_user.stripe_onboarding_complete?

    if @project.id == 1053
      @bg_sm = "bg-small"
    end

    if params[:partner_id]
      @partner = Partner.find_by_permalink(params[:partner_id])
      render layout: 'application_partner' and return
    end
  end


  def comments
    @project = resource
  end

  def pay
    authorize resource
    @project = resource
    @stripe_onboarding_complete = current_user.respond_to?(:stripe_onboarding_complete?) &&
                                   current_user.stripe_onboarding_complete?
  end

  def request_payout
    @project = resource

    unless user_signed_in? && current_user == @project.user
      flash[:alert] = "Accès non autorisé."
      return redirect_to project_path(@project)
    end

    unless @project.use_stripe?
      flash[:alert] = "Les paiements en ligne ne sont pas encore activés pour ce projet."
      return redirect_to pay_project_path(@project)
    end

    # Le porteur DOIT avoir configuré Stripe avant de demander le virement
    # (l'admin en aura besoin pour effectuer le transfert)
    unless current_user.stripe_onboarding_complete?
      flash[:alert] = I18n.t('stripe.payout.onboarding_required',
        default: 'Vous devez d\'abord configurer votre espace de virement pour recevoir vos fonds.')
      return redirect_to pay_project_path(@project)
    end

    # Virement déjà effectué
    if @project.stripe_settlement_type == 'transferred' || @project.stripe_transfer_id.present?
      flash[:notice] = "Vos fonds ont déjà été virés sur votre compte bancaire."
      return redirect_to pay_project_path(@project)
    end

    # Demande déjà en cours de traitement
    if @project.state == 'request_funds'
      flash[:notice] = "Votre demande de virement est déjà en cours de traitement par notre équipe."
      return redirect_to pay_project_path(@project)
    end

    # Vérifier qu'il y a des contributions à virer
    contributions = @project.contributions
                            .where(payment_method: 'Stripe', state: 'confirmed')
                            .where(stripe_refunded: [false, nil], stripe_transferred: [false, nil])
    if contributions.empty?
      flash[:alert] = "Aucune contribution confirmée à virer pour ce projet."
      return redirect_to pay_project_path(@project)
    end

    begin
      # FLUX CROWDFUNDING CORRECT:
      # 1. Porteur initie → projet passe en request_funds + admin notifié
      # 2. Admin décide de payer → process_stripe_transfer (panel admin)
      # 3. CampaignSettlement effectue le Stripe Transfer → auto-payout vers banque porteur
      if @project.can_push_to_request_funds?
        @project.push_to_request_funds!

        total = contributions.sum(:value)
        fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').tr(',', '.').to_f / 100
        net = (total * (1 - fee_pct)).round(2)

        # Notifier l'admin par email
        begin
          @project.notify_observers(:from_online_to_request_funds)
        rescue => notify_err
          Rails.logger.warn "request_payout: notification admin échouée - #{notify_err.message}"
        end

        flash[:success] = "✅ Demande de virement de #{net}€ envoyée ! Notre équipe va vérifier et virer les fonds directement sur votre compte bancaire. Vous recevrez une confirmation par email."
      else
        flash[:alert] = "Impossible de soumettre la demande depuis l'état actuel du projet (#{@project.state})."
      end
    rescue => e
      Rails.logger.error "ProjectsController#request_payout: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      flash[:alert] = "Erreur technique : #{e.message}"
    end

    redirect_to pay_project_path(@project)
  end

  def reports
    authorize resource
  end

  def budget
    @project = resource
  end

  def english
    @project = resource
  end


  %w(embed video_embed).each do |method_name|
    define_method method_name do
      @title = resource.name
      render layout: 'embed'
    end
  end

  def embed_panel
    @project = resource
    render layout: !request.xhr?
  end

  def start
    @projects = ProjectsForHome.successful[0..3]
    @channel  = channel.decorate if channel
  end

  def coaching
  end

  def consulting
  end

  def crowdfunding
    projects_vars = {
      coming_soon: :soon,
      ending_soon: :expiring,
      featured:    :featured,
      recommended: :recommends,
      successful:  :successful
    }
    projects_vars.each do |var_name, scope|
      instance_variable_set "@#{var_name}", ProjectsForHome.send(scope)
    end
 
    @successful = @successful.take(2) if browser.device.mobile?
    @channels = Channel.with_state('online').order('RANDOM()').limit(4)
    @press_assets = PressAsset.order('created_at DESC').limit(5)
  end
 

  private

  def permitted_params
    params.permit(policy(@project || Project).permitted_attributes)
  end

  def resource
    @project ||= Project.find_by_permalink!(params[:id])
  end

  def has_project_prerequisites?
    current_user.try(:mobile_phone).present?
  end

  def has_prerequisites
    if user_signed_in?
      if current_user.light_authentication_ready? && has_project_prerequisites?
        return true
      else
        messages = []
        messages << t('projects.new.profile_incomplete', default: 'Veuillez compléter votre profil') unless current_user.light_authentication_ready?
        messages << t('projects.new.missing_mobile_phone_for_new_project') unless has_project_prerequisites?
        flash.alert = messages.join('<br/>').html_safe
        redirect_to edit_user_path(current_user, redirect_url: new_project_path) and return false
      end
    else
      redirect_to new_user_session_path
    end
  end
end
