class Projects::BuildController < ApplicationController
  include Wicked::Wizard

  steps :step1, :step2, :step3, :step4, :verify

  before_action :fetch_project
  after_action :save_project

  
  def show
    redirect_to new_user_session_path and return unless user_signed_in?

    if params[:partner].present?
      @partner = Partner.find_by(permalink: params[:partner])
      cookies[:new_project_partner_id] = @partner.id
    elsif cookies[:new_project_partner_id].present?
      @partner = Partner.find_by(id: cookies[:new_project_partner_id])
    end

    render_wizard
  end

  def update
    redirect_to new_user_session_path and return unless user_signed_in?

    puts permitted_params[:project].inspect

    @project.assign_attributes(permitted_params[:project])

    if permitted_params[:project][:partner_id].present?
      partner_id = permitted_params[:project][:partner_id]
      @partner = Partner.find_by(id: partner_id)
    elsif cookies[:new_project_partner_id].present?
      partner_id = cookies[:new_project_partner_id]
      @partner = Partner.find_by(id: partner_id)
    end

    if @partner.present?
      puts @partner.inspect
      @project.partner = @partner
    end

    puts @project.inspect

    puts step.inspect

    # Only save project on last step; meanwhile the cache keep it
    if step == :step1
      if permitted_params[:project][:presale] == "1"
        @project.assign_attributes(goal: 0)
      end

      Rails.logger.debug("Skiping wicked save, step: #{step}, last step: #{Wicked::LAST_STEP}, finish step: #{Wicked::FINISH_STEP}")
      @skip_to = @next_step
      render_wizard
    elsif step == :verify
      # Dernière étape : sauvegarder le projet en base de données
      Rails.logger.debug("## Tentative de sauvegarde du projet")
      Rails.logger.debug("## Projet: #{@project.inspect}")
      Rails.logger.debug("## Erreurs avant save: #{@project.errors.full_messages}")
      
      if @project.save
        Rails.logger.debug("## Projet sauvegardé avec succès, ID: #{@project.id}")
        render_wizard @project
      else
        Rails.logger.error("## ERREUR: Échec de sauvegarde du projet")
        Rails.logger.error("## Erreurs: #{@project.errors.full_messages}")
        
        flash.now[:alert] = "Impossible de créer le projet : #{@project.errors.full_messages.join(', ')}"
        render_wizard
      end
    else
      Rails.logger.debug("Skiping wicked save, step: #{step}, last step: #{Wicked::LAST_STEP}, finish step: #{Wicked::FINISH_STEP}")
      @skip_to = @next_step
      render_wizard
    end
  end

  def redirect_to_finish_wizard(options = {}, params = {})
    Rails.logger.debug("## Saving draft for notification")
    Rails.logger.debug("## #{@project.inspect}")
    Rails.cache.write("project_#{@project.id}_draft", @project, expires_in: 12.hours)

    Rails.logger.debug('## Removing draft for form')
    Rails.cache.delete(project_cache_key)
    super(params.merge({ notice: "Votre projet a été créé! Nous vous reviendrons sous 72h. En attendant peaufinez votre présentation"}))
  end

  def finish_wizard_path
    Rails.logger.debug("****************************************************")
    Rails.logger.debug("project : #{@project.inspect}")
    Rails.logger.debug("project ID : #{@project.id}")
    Rails.logger.debug("project permalink : #{@project.permalink}")
    Rails.logger.debug("****************************************************")
    Rails.logger.debug("partner : #{@project.partner.inspect}")
    Rails.logger.debug("****************************************************")

    # Vérifier que le projet a bien un ID et un permalink
    unless @project.persisted? && @project.permalink.present?
      Rails.logger.error("## ERREUR: finish_wizard_path appelé avec un projet non sauvegardé")
      Rails.logger.error("## Projet persisted?: #{@project.persisted?}")
      Rails.logger.error("## Projet ID: #{@project.id}")
      Rails.logger.error("## Projet permalink: #{@project.permalink}")
      Rails.logger.error("## Erreurs: #{@project.errors.full_messages}")
      return projects_path
    end

    if @project.partner.present?
      partner_project_path(partner_id: @project.partner.permalink, id: @project.permalink)
    else
      project_path(@project)
    end
  end

  private

  def project_cache_key
    "project_draft_#{current_user.try(:id)}"
  end

  def fetch_project
    @project = Rails.cache.fetch(project_cache_key, expires_in: 1.hours) do
      Project.new(user: current_user, campaign_type: :all_or_none)
    end
    authorize @project
  end

  def save_project
    Rails.cache.write(project_cache_key, @project) unless step == Wicked::FINISH_STEP
  end

  def permitted_params
    permitted = policy(@project || Project.new).permitted_attributes
    
    permitted[:project] << [:description, :how_knows_fiatope, :how_knows_crowdfunding, :already_did_crowdfunding, :presale]
    permitted[:project] << [:how_many_contributors, :how_much_contribute, :contributors_from_where, :enrollment_strategy]
    permitted[:project] << [:partner_id]

    Project::CROWDFUNDING_SOCIAL_NETWORKS.each do |network|
      permitted[:project] << [network, "#{network}_followers"]
    end

    permitted[:project] << [:need_support, :join_follow_program, :organization, :organization_type, :organization_description, :organization_created_at, :organization_in_incubateur, :organization_funding]

    params.permit(permitted)
  end
end
