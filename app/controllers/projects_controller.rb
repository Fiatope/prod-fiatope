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
    projects = public_map_scope
    @map_projects = public_map_projects(projects)
    @map_stats = public_map_stats(projects)
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
    @organization_registration_number = current_user.organization.respond_to?(:registration_number) ? current_user.organization&.registration_number : nil
    @payout_profile_complete = current_user.payout_profile_complete?
    @stripe_payout_ready = @payout_profile_complete &&
                           current_user.stripe_connect_account_id.present? &&
                           current_user[:stripe_onboarding_complete] == true
    @payout_profile_missing_fields = current_user.payout_profile_missing_fields
  end

  def update_payout_profile
    authorize resource, :pay?
    @project = resource

    unless user_signed_in? && current_user == @project.user
      flash[:alert] = 'Accès non autorisé.'
      return redirect_to project_path(@project)
    end

    unless payout_profile_single_representative_attested?
      flash[:alert] = 'Vous devez cocher l’attestation avant d’envoyer vos informations et documents.'
      return redirect_to pay_project_path(@project)
    end

    unless payout_profile_tos_accepted?
      flash[:alert] = payout_profile_acceptance_required_message
      return redirect_to pay_project_path(@project)
    end

    begin
      ActiveRecord::Base.transaction do
        current_user.assign_attributes(payout_profile_user_params)
        current_user.profile_type = payout_profile_type_for_platform
        current_user.save!

        if current_user.profile_type == 'organization'
          organization = current_user.organization || current_user.build_organization
          organization.name = payout_profile_organization_name
          organization.registration_number = payout_profile_organization_registration_number if organization.respond_to?(:registration_number=)
          if organization.respond_to?(:payout_single_representative_attested_at=)
            organization.payout_single_representative_attested_at =
              payout_profile_single_representative_attested? ? Time.current : nil
          end
          organization.save!
        end

        bank_information = current_user.bank_information || current_user.build_bank_information
        apply_payout_bank_reference!(bank_information, payout_profile_bank_params)
        bank_information.save!

        update_or_create_kyc_documents!(current_user)
      end

      sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(
        current_user,
        request_ip: request.remote_ip,
        user_agent: request.user_agent,
        tos_accepted: payout_profile_tos_accepted?
      )
      if sync_result.success?
        clear_payout_profile_edit_unlock!(current_user)
        if sync_result.warnings.any?
          Rails.logger.warn "Payout profile sync warnings for user #{current_user.id}: #{sync_result.warnings.join(', ')}"
          flash[:notice] = 'Vos documents de paiement ont été enregistrés. Nous vous contacterons si une information doit être corrigée.'
        else
          flash[:success] = 'Vos documents de paiement ont été enregistrés avec succès.'
        end
      else
        Rails.logger.warn "Payout profile sync failed for user #{current_user.id}: #{sync_result.errors.join(', ')}"
        if payout_profile_internal_sync_issue?(sync_result.errors)
          clear_payout_profile_edit_unlock!(current_user)
          flash[:notice] = payout_profile_sync_failure_message(sync_result.errors)
        else
          unlock_payout_profile_edit_for_retry!(current_user)
          flash[:alert] = payout_profile_sync_failure_message(sync_result.errors)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = e.record.errors.full_messages.to_sentence
    rescue => e
      Rails.logger.error "ProjectsController#update_payout_profile: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      flash[:alert] = 'Erreur technique lors de l’envoi des documents de paiement. Vérifiez vos justificatifs et réessayez.'
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

    # Le porteur doit avoir envoyé les documents de paiement dans la plateforme.
    unless current_user.payout_profile_complete?
      flash[:alert] = 'Vous devez d’abord envoyer les documents nécessaires au paiement avant de demander le paiement.'
      return redirect_to pay_project_path(@project)
    end

    payout_status = @project.stripe_payout_status.to_s
    if @project.state == 'paid' || payout_status == 'paid'
      flash[:notice] = "Vos fonds ont déjà été confirmés comme reçus sur votre compte bancaire."
      return redirect_to pay_project_path(@project)
    end

    if %w[pending in_transit].include?(payout_status)
      flash[:notice] = "Votre paiement est en cours. Vous recevrez un email lorsque les fonds seront arrivés sur votre compte."
      return redirect_to pay_project_path(@project)
    end

    if payout_status == 'manual_review'
      flash[:notice] = "Votre demande de paiement est en cours. Nous vous contacterons s’il manque une information."
      return redirect_to pay_project_path(@project)
    end

    if @project.stripe_settlement_type == 'transferred' || @project.stripe_transfer_id.present?
      flash[:notice] = "Votre paiement est déjà en cours."
      return redirect_to pay_project_path(@project)
    end

    # Demande déjà en cours de traitement
    if @project.state == 'request_funds'
      flash[:notice] = "Votre demande de paiement est déjà en cours."
      return redirect_to pay_project_path(@project)
    end

    # Vérifier qu'il y a des contributions à payer
    contributions = @project.contributions
                            .where(payment_method: 'Stripe', state: 'confirmed')
                            .where(stripe_refunded: [false, nil], stripe_transferred: [false, nil])
    if contributions.empty?
      flash[:alert] = "Aucune contribution confirmée à payer pour ce projet."
      return redirect_to pay_project_path(@project)
    end

    # Synchroniser les informations locales avant de soumettre la demande.
    sync_result = Neighborly::Stripe::PayoutProfileSyncService.call(
      current_user,
      request_ip: request.remote_ip,
      user_agent: request.user_agent
    )
    unless sync_result.success?
      Rails.logger.warn "Payout request profile sync failed for user #{current_user.id}: #{sync_result.errors.join(', ')}"
      if payout_profile_internal_sync_issue?(sync_result.errors)
        flash[:notice] = payout_profile_sync_failure_message(sync_result.errors)
      else
        unlock_payout_profile_edit_for_retry!(current_user)
        flash[:alert] = payout_profile_sync_failure_message(sync_result.errors)
      end
      return redirect_to pay_project_path(@project)
    end

    begin
      # FLUX CROWDFUNDING CORRECT:
      # 1. Porteur initie → projet passe en request_funds + admin notifié
      # 2. Admin décide de payer → process_stripe_transfer (panel admin)
      # 3. CampaignSettlement effectue le transfert et le paiement vers la banque du porteur
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

        flash[:success] = "Votre demande de paiement de #{net} EUR a bien été envoyée. Vous recevrez un email de confirmation."
      else
        flash[:alert] = "Impossible de soumettre la demande depuis l'état actuel du projet (#{@project.state})."
      end
    rescue => e
      Rails.logger.error "ProjectsController#request_payout: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      flash[:alert] = 'Erreur technique lors de la demande de paiement. Veuillez réessayer.'
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

  def public_map_scope
    Project.visible
           .where(state: public_map_states)
           .where.not(latitude: nil, longitude: nil)
           .joins(:contributions)
           .where(contributions: { state: 'confirmed' })
           .includes(:category, :project_total)
           .order('projects.updated_at DESC')
           .distinct
  end

  def public_map_projects(projects = public_map_scope)
    projects.map do |project|
      {
        id: project.id,
        name: project.name.to_s,
        headline: project.headline.to_s,
        summary: public_map_summary(project),
        location: project.location.to_s,
        latitude: project.latitude.to_f,
        longitude: project.longitude.to_f,
        state: project.state.to_s,
        state_label: public_map_state_label(project.state.to_s),
        category_name: project.category&.name_pt.to_s.presence || project.category&.name_en.to_s,
        goal: project.goal.to_f,
        pledged: project.project_total&.pledged.to_f,
        total_contributions: project.project_total&.total_contributions.to_i,
        image_url: public_map_image_url(project),
        fallback_image_url: public_map_fallback_image_url,
        permalink: project.permalink.to_s,
        project_url: project_path(project)
      }
    end
  end

  def public_map_stats(projects)
    project_ids = projects.pluck(:id)
    return { projects_count: 0, total_contributions: 0, total_collected: 0.0 } if project_ids.empty?

    confirmed_contributions = Contribution.where(project_id: project_ids, state: 'confirmed')

    {
      projects_count: project_ids.size,
      total_contributions: confirmed_contributions.count,
      total_collected: confirmed_contributions.sum(:value).to_f
    }
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

  def public_map_summary(project)
    source = project.about_html.presence || project.about.to_s
    text = helpers.strip_tags(source.to_s)
    text = text.gsub(/\s+/, ' ').strip
    helpers.truncate(text, length: 320, separator: ' ')
  end

  def public_map_image_url(project)
    main_image = project.display_image('project_thumb_large').to_s

    if main_image.blank? || main_image.include?('image-placeholder-upload-in-progress.jpg')
      hero_image = project.hero_image_url(:blur).to_s.presence || project.hero_image_url.to_s.presence
      main_image = hero_image.presence || public_map_fallback_image_url
    end

    normalize_public_map_image_url(main_image)
  rescue StandardError
    public_map_fallback_image_url
  end

  def normalize_public_map_image_url(raw_url)
    url = raw_url.to_s.strip
    return public_map_fallback_image_url if url.blank?
    return url if url.start_with?('http://', 'https://', '//', '/')

    helpers.image_url(url)
  end

  def public_map_fallback_image_url
    helpers.image_url('banner.jpg')
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

  def payout_profile_organization_registration_number
    params[:organization_registration_number].to_s.strip.upcase
  end

  def payout_profile_single_representative_attested?
    params[:organization_single_representative_attestation].to_s == '1'
  end

  def payout_profile_kyc_types_for(user)
    user.payout_profile_required_kyc_types
  end

  def payout_profile_bank_reference_type(user)
    'iban'
  end

  def payout_profile_bank_reference_value(user)
    user.bank_information&.iban
  end

  def apply_payout_bank_reference!(bank_information, bank_params)
    attrs = bank_params.to_h.symbolize_keys
    attrs.delete(:bank_reference_type)
    reference_value = attrs.delete(:bank_reference_value)
    iban_country = payout_profile_iban_country(reference_value)
    attrs[:other_country] = iban_country if iban_country.present?

    bank_information.assign_attributes(attrs)
    bank_information.apply_payout_bank_reference(type: 'iban', value: reference_value)
  end

  def payout_profile_iban_country(value)
    value.to_s.upcase.gsub(/\s+/, '')[/\A[A-Z]{2}/]
  end

  def payout_profile_type_for_platform
    'organization'
  end

  def payout_profile_kyc_labels
    User::PAYOUT_KYC_LABELS
  end

  def payout_profile_tos_accepted?
    params[:stripe_tos_acceptance].to_s == '1'
  end

  def payout_profile_acceptance_required_message
    'Vous devez cocher l’attestation avant d’envoyer vos informations et documents.'
  end

  def payout_profile_internal_sync_issue?(errors)
    Array(errors).join(' ').match?(
      /account token|business_type|jeton sécurisé|configuration|api key|responsibilities of collecting requirements|platform-profile|platform profile|collecting requirements|cannot change.*verification.*document|account is verified|legal entity information/i
    )
  end

  def payout_profile_sync_failure_message(errors)
    details = Array(errors).join(' ')

    if payout_profile_internal_sync_issue?(errors)
      return 'Vos informations et documents ont été envoyés. Notre équipe finalise une vérification avant le paiement et vous contactera seulement si une action est nécessaire.'
    end

    if details.match?(/valid phone number|phone/i)
      return 'Le numéro de téléphone doit être au format international. Exemple: +237654770064.'
    end

    if details.match?(/not currently supported|not supported/i)
      return 'Le pays choisi pour le compte bancaire ne permet pas encore de recevoir ce paiement. Utilisez un IBAN dans un pays pris en charge ou contactez notre équipe.'
    end

    if details.match?(/postal|zip/i)
      return 'Le code postal semble invalide. Vérifiez le code postal du titulaire du compte.'
    end

    if details.match?(/iban|bank account|account_number|routing/i)
      return 'Les informations bancaires semblent invalides. Vérifiez l’IBAN et le pays du compte bancaire.'
    end

    if details.match?(/date of birth|dob|birthday/i)
      return 'La date de naissance semble invalide. Vérifiez le champ date de naissance.'
    end

    if details.match?(/address|city|country|line1/i)
      return 'L’adresse du titulaire semble incomplète ou invalide. Vérifiez l’adresse, la ville, le pays et le code postal.'
    end

    if details.match?(/document|file|upload/i)
      return 'Un justificatif n’a pas pu être vérifié. Vérifiez que le fichier est lisible, complet et au format demandé, puis renvoyez-le.'
    end

    if details.match?(/conditions de paiement|accepter les conditions|conditions/i)
      return payout_profile_acceptance_required_message
    end

    'Vos informations et documents ont été envoyés. Nous vous contacterons seulement si une correction est nécessaire.'
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

  def unlock_payout_profile_edit_for_retry!(user)
    Rails.cache.write(
      payout_profile_edit_unlock_cache_key(user),
      { unlocked_at: Time.current.to_i, reason: 'sync_failed' },
      expires_in: 14.days
    )
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
