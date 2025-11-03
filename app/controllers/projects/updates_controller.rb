class Projects::UpdatesController < ApplicationController
  after_action :verify_authorized, except: :index
  inherit_resources
  actions :destroy
  belongs_to :project, finder: :find_by_permalink!

  def index
    @project = parent
    if request.xhr? && params[:page] && params[:page].to_i > 1
      render collection
    end
  end

  def create
    @update = Update.new(permitted_params[:update].
                         merge(project: parent, user: current_user))
    authorize @update
    @update.save

    @project = Project.find(@update.project_id)

    flash.notice = "Mise à jour envoyé avec succès."

    respond_to do |format|
      # format.js # actually means: if the client ask for js -> return file.js
      format.js   { render :js => "window.location='#{ project_updates_path(project_id: @project.permalink) }'" }
    end

    #render @update
  end

  def destroy
    authorize resource
    destroy! do
      if request.xhr?
        return render nothing: true
      else
        project_updates_path(parent)
      end
    end
  end

  private
  def permitted_params
    params.permit(policy(@update || Update).permitted_attributes)
  end

  def collection
    @updates ||= policy_scope(end_of_association_chain).order('created_at desc').page(params[:page]).per(3)
  end
end
