module Neighborly::Admin
  class ProjectsController < BaseController
    defaults finder: :find_by_permalink!

    has_scope :by_user_email, :by_id, :pg_search, :user_name_contains, :with_state, :by_category_id, :order_by
    has_scope :between_created_at, :between_expires_at, :between_online_date, :between_updated_at, :goal_between, using: [ :start_at, :ends_at ]

    before_action do
      @total_projects = Project.count
    end

    [:launch, :reject, :push_to_draft, :push_to_request_funds, :push_to_fraud_suspiscion, :push_to_paid, :approve].each do |name|
      define_method name do
        @project = Project.find_by_permalink params[:id]
        @project.send("#{name.to_s}!")
        redirect_back(fallback_location: root_path)
      end
    end

    def show_project_on_homepage
      @projects_show_on_homepage = Project.projects_to_show_on_home_page.count

      if @projects_show_on_homepage == 3
        flash[:alert] = "Trois cagnottes on été déja mis en page d'accueil!"
      elsif @projects_show_on_homepage < 3
        @project = Project.find_by(permalink: params[:id])

        if @project.present?
          @project.show_on_homepage = true
          @project.save

          flash[:success] = "Success!"
        else
          flash[:error] = "Projet introuvable!"
        end
      end

      redirect_back(fallback_location: root_path)
    end

    def remove_project_on_homepage
      @project = Project.find_by(permalink: params[:id])

      if @project.present?
        if @project.show_on_homepage
          @project.show_on_homepage = false
          @project.save

          flash[:success] = "Success!"
        end
      else
        flash[:error] = "Projet introuvable!"
      end

      redirect_back(fallback_location: root_path)
    end

    def populate
      if params[:user][:id].present?
        @user = User.find(params[:user][:id])
      else
        @user = create_user
      end

      @contribution = build_contribution(@user)

      if @user.valid? and @contribution.valid?
        @user.save!
        @contribution.save!
        redirect_to populate_contribution_project_path(resource), flash: { success: 'Success!' }
      else
        flash.alert = (@user.errors.full_messages +
                       @contribution.errors.full_messages).to_sentence
        render :populate_contribution
      end
    end

    def destroy
      resource.push_to_trash! if resource.can_push_to_trash?
      redirect_to projects_path
    end

    protected
    def collection
      @projects = apply_scopes(end_of_association_chain).order('projects.created_at desc').without_state('deleted').page(params[:page])
    end

    def create_user
      password = Devise.friendly_token
      user = User.new(user_params[:user])
      user.email = "#{Devise.friendly_token}@populate.user"
      user.password = password
      user.password_confirmation = password
      user.profile_type = user_params[:user][:profile_type]
      user
    end

    def build_contribution(user)
      contribution = resource.contributions.new(contribution_params[:contribution])
      contribution.payment_method = 'PrePopulate'
      contribution.state = 'confirmed'
      contribution.user = user
      contribution
    end

    def user_params
      params.permit({ user: User.attribute_names.map(&:to_sym) })
    end

    def contribution_params
      params.permit({ contribution: Contribution.attribute_names.map(&:to_sym) })
    end

    def permitted_params
      params.permit({ project: Project.attribute_names.map(&:to_sym) })
    end
  end
end
