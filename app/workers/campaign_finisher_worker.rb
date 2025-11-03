class CampaignFinisherWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform project_id
    resource = Project.find project_id
    Rails.logger.info "[FUNDING PROJECT #{resource.id}] #{resource.name}"
    resource.finish
  end
end
