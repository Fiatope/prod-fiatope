# coding: utf-8
class ProjectsController < ApplicationController
  after_action :verify_authorized, except: [:index, :video, :video_embed, :embed,
                                            :embed_panel, :comments, :budget, :english,
                                            :reward_contact, :send_reward_email,
                                            :start, :coaching, :crowdfunding, :consulting, :change_recommended]

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
    respond_with(Project.update(resource.id, permitted_params[:project].merge!(address_state: resource.address_state.capitalize)), location: project_path(@project))
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

    puts "****************************************************"
    puts "avant : #{@project.inspect}"
    puts "****************************************************"

    @project = resource
    
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
        messages << t('projects.new.not_mangopay_ready') unless current_user.light_authentication_ready?
        messages << t('projects.new.missing_mobile_phone_for_new_project') unless has_project_prerequisites?
        flash.alert = messages.join('<br/>').html_safe
        redirect_to edit_user_path(current_user, redirect_url: new_project_path) and return false
      end
    else
      redirect_to new_user_session_path
    end
  end
end
