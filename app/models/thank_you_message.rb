class ThankYouMessage < ActiveRecord::Base
  include Shared::Notifiable

  belongs_to :project
  validates :project, presence: true

  after_save :notify_contributors

  def notify_contributors
    return true if dismissed?
    project.contributions.find_each { |c| c.notify_owner(:thank_you_from_project_owner) }
    self.update_column(:dismissed, true)
  end

end
