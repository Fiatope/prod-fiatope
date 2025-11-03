class Reports::ContributionReportsForProjectOwnersController < Reports::BaseController
  before_action :check_if_project_belongs_to_user

  def index
    reward_id  = params[:reward_id]
    conditions = if reward_id
      { reward_id: (reward_id == '0' ? nil : reward_id) }
    else
      {}
    end

    project = Project.find(params[:project_id])
    reports = ContributionReportsForProjectOwner.new(project, conditions)

    puts "reportsss, #{reports.to_json}"
    respond_to do |format|
      format.csv do
        send_data reports.to_csv, filename: "reports-#{Date.today}.xls"
      end
    end
  end

  def end_of_association_chain
    reward_id  = params[:reward_id]
    conditions = if reward_id
      { reward_id: (reward_id == '0' ? nil : reward_id) }
    else
      {}
    end

    project = Project.find(params[:project_id])
    ContributionReportsForProjectOwner.new(project, conditions)
  end

  def check_if_project_belongs_to_user
    redirect_to root_path unless policy(Project.find(params[:project_id])).update?
  end
end
