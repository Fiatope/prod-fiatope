class RewardsController < ApplicationController
  after_action :verify_authorized, except: :index
  helper_method :parent
  respond_to :html

  def index
    @rewards = parent.rewards.rank(:row_order)
    respond_with @rewards, layout: !request.xhr?
  end

  def new
    @reward = Reward.new(project: parent)
    authorize @reward
    @reward.articles.build if @reward.project.presale?
    respond_with @reward, layout: !request.xhr?
  end

  def create
    @reward = Reward.new(permitted_params[:reward].merge(project: parent))
    authorize @reward
    @reward.save

    project = @reward.project

    if project.presale?
      goal = 0

      project.rewards.each do |reward|
        goal += reward.minimum_value * reward.maximum_contributions
      end

      project.update(goal: goal)
    end

    respond_with @reward, location: project_path(parent)
  end


  def contribution
    authorize resource
    @contribution = ContributionForm.new(reward_id: resource.id, value: resource.minimum_value, user: current_user, project: parent)

    if @contribution.save
      session[:thank_you_contribution_id] = @contribution.id
      flash.delete(:notice)
      redirect_to edit_project_contribution_path(project_id: parent, id: @contribution.id)
    else
      flash.alert = t('controllers.projects.contributions.create.error')
      redirect_to project_path(@project)
    end
  end

  def edit
    authorize resource
    respond_with resource, layout: !request.xhr?
  end

  def update
    authorize resource
    respond_with Reward.update(resource.id, permitted_params[:reward]),
      location: project_path(parent)
  end

  def destroy
    authorize resource
    resource.delete
    respond_with resource, location: project_path(parent)
  end

  def sort
    authorize resource
    resource.update :row_order_position, params[:reward][:row_order_position]

    render nothing: true
  end

  private

  def resource
    @reward ||= parent.rewards.find(params[:id])
  end

  def parent
    @project ||= Project.find_by_permalink!(params[:project_id])
  end

  def permitted_params
    params.permit(policy(@reward || Reward).permitted_attributes)
  end
end
