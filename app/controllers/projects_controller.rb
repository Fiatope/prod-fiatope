# coding: utf-8
class ProjectsController < ApplicationController
  after_action :verify_authorized, except: [:index, :video, :video_embed, :embed,
                                            :embed_panel, :comments, :budget, :english,
                                            :reward_contact, :send_reward_email,
                                            :start, :coaching, :crowdfunding, :consulting, :change_recommended,
                                            :request_payout, :public_map]

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

  def public_map
    @map_projects = public_map_projects
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

    # Le statut de readiness pour retirer les fonds est base sur le profil local.
    @payout_profile_complete = user_signed_in? && current_user == @project.user &&
                   current_user.payout_profile_complete?

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
    current_user.profile_type = payout_profile_type_for_platform
    @payout_profile_edit_unlocked = payout_profile_edit_unlocked?(current_user)
    @bank_information = current_user.bank_information || current_user.build_bank_information
    @bank_reference_type = payout_profile_bank_reference_type(current_user)
    @bank_reference_value = payout_profile_bank_reference_value(current_user)
    @required_kyc_types = payout_profile_kyc_types_for(current_user)
    @required_kyc_labels = payout_profile_kyc_labels
    @kyc_documents_by_type = current_user.kycs.where(proof_type: @required_kyc_types)
                                        .order(created_at: :desc)
                                        .group_by(&:proof_type)
    @organization_name = current_user.organization&.name
    @payout_profile_complete = current_user.payout_profile_complete?
    @payout_profile_missing_fields = current_user.payout_profile_missing_fields
  end

  def update_payout_profile
    authorize resource, :pay?
    @project = resource

    unless user_signed_in? && current_user == @project.user
      flash[:alert] = 'Acces non autorise.'
      return redirect_to project_path(@project)
    end

    begin
      ActiveRecord::Base.transaction do
        current_user.assign_attributes(payout_profile_user_params)
        current_user.profile_type = payout_profile_type_for_platform
        current_user.save!

        if current_user.profile_type == 'organization'
          organization = current_user.organization || current_user.build_organization
          organization.name = payout_profile_organization_name
          organization.save!
        end

        bank_information = current_user.bank_information || current_user.build_bank_information
        apply_payout_bank_reference!(bank_information, payout_profile_bank_params)
        bank_information.save!

        update_or_create_kyc_documents!(current_user)
      end

      clear_payout_profile_edit_unlock!(current_user)

      sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(current_user)
      if sync_result.success?
        if sync_result.warnings.any?
          flash[:notice] = "Profil enregistre. Synchronisation Stripe partielle: #{sync_result.warnings.join(', ')}"
        else
          flash[:success] = 'Votre profil de retrait a ete enregistre avec succes.'
        end
      else
        flash[:alert] = "Profil enregistre localement, mais la synchronisation Stripe a echoue: #{sync_result.errors.join(', ')}"
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = e.record.errors.full_messages.to_sentence
    rescue => e
      Rails.logger.error "ProjectsController#update_payout_profile: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      flash[:alert] = 'Erreur technique lors de la sauvegarde du profil de retrait. Verifiez vos justificatifs et reessayez.'
    end

    redirect_to pay_project_path(@project)
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

    # Le porteur doit avoir complete son profil de retrait dans la plateforme.
    unless current_user.payout_profile_complete?
      flash[:alert] = 'Vous devez d abord completer votre profil de retrait (identite, banque, justificatifs) avant de demander le virement.'
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

    # Synchroniser les informations locales vers Stripe avant de soumettre la demande.
    sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(current_user)
    unless sync_result.success?
      flash[:alert] = "Impossible de synchroniser le profil de retrait vers Stripe: #{sync_result.errors.join(', ')}"
      return redirect_to pay_project_path(@project)
    end

    begin
      # FLUX CROWDFUNDING CORRECT:
      # 1. Porteur initie → projet passe en request_funds + admin notifié
      # 2. Admin décide de payer → process_stripe_transfer (panel admin)
      # 3. CampaignSettlement effectue le Stripe Transfer → auto-payout vers banque porteur
      if @project.can_push_to_request_funds?
        @project.push_to_request_funds!
        clear_payout_profile_edit_unlock!(current_user)

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
      flash[:alert] = 'Erreur technique lors de la demande de virement. Veuillez reessayer.'
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

  def public_map_projects
    projects = Project.visible
                      .where(state: public_map_states)
                      .where.not(latitude: nil, longitude: nil)
                      .joins(:contributions)
                      .where(contributions: { state: 'confirmed' })
                      .includes(:category, :project_total)
                      .order('projects.updated_at DESC')
                      .distinct

    projects.map do |project|
      {
        id: project.id,
        name: project.name.to_s,
        headline: project.headline.to_s,
        summary: helpers.truncate(helpers.strip_tags(project.about.to_s), length: 190),
        location: project.location.to_s,
        latitude: project.latitude.to_f,
        longitude: project.longitude.to_f,
        state: project.state.to_s,
        state_label: public_map_state_label(project.state.to_s),
        category_name: project.category&.name_pt.to_s.presence || project.category&.name_en.to_s,
        goal: project.goal.to_f,
        pledged: project.project_total&.pledged.to_f,
        total_contributions: project.project_total&.total_contributions.to_i,
        image_url: project.uploaded_image&.url.to_s,
        permalink: project.permalink.to_s,
        project_url: project_path(project)
      }
    end
  end

  def public_map_states
    %w[successful paid]
  end

  def public_map_state_label(state)
    case state
    when 'successful', 'paid'
      'Accompli'
    else
      state.to_s.humanize
    end
  end

  def has_project_prerequisites?
    current_user.try(:mobile_phone).present?
  end

  def payout_profile_user_params
    params.permit(:profile_type, :name, :birthday, :nationality, :residence_country, :mobile_phone)
  end

  def payout_profile_bank_params
    params.permit(:owner_address, :owner_city, :owner_region, :owner_postal_code, :other_country, :bank_reference_type, :bank_reference_value)
  end

  def payout_profile_organization_name
    params[:organization_name].to_s.strip
  end

  def payout_profile_kyc_types_for(user)
    user.payout_profile_required_kyc_types
  end

  def payout_profile_bank_reference_type(user)
    user.bank_information&.payout_bank_reference_type || 'iban'
  end

  def payout_profile_bank_reference_value(user)
    user.bank_information&.payout_bank_reference_value
  end

  def apply_payout_bank_reference!(bank_information, bank_params)
    attrs = bank_params.to_h.symbolize_keys
    reference_type = attrs.delete(:bank_reference_type)
    reference_value = attrs.delete(:bank_reference_value)

    bank_information.assign_attributes(attrs)
    bank_information.apply_payout_bank_reference(type: reference_type, value: reference_value)
  end

  def payout_profile_type_for_platform
    'organization'
  end

  def payout_profile_kyc_labels
    User::PAYOUT_KYC_LABELS
  end

  def payout_profile_edit_unlock_cache_key(user)
    "payout_profile_edit_unlock:user:#{user.id}"
  end

  def payout_profile_edit_unlocked?(user)
    Rails.cache.read(payout_profile_edit_unlock_cache_key(user)).present?
  end

  def clear_payout_profile_edit_unlock!(user)
    Rails.cache.delete(payout_profile_edit_unlock_cache_key(user))
  end

  def update_or_create_kyc_documents!(user)
    return if params[:kyc_files].blank?

    required_types = payout_profile_kyc_types_for(user)
    kyc_files = params[:kyc_files]
    kyc_files = kyc_files.to_unsafe_h if kyc_files.respond_to?(:to_unsafe_h)

    kyc_files.each do |proof_type, uploaded_images|
      next unless required_types.include?(proof_type.to_s)

      files = uploaded_images.is_a?(Array) ? uploaded_images : [uploaded_images]
      files = files.compact.reject(&:blank?)
      next if files.empty?

      user.kycs.where(proof_type: proof_type.to_s).destroy_all

      files.each do |uploaded_image|
        user.kycs.create!(proof_type: proof_type.to_s, uploaded_image: uploaded_image)
      end
    end
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
