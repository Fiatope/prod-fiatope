class UpdateObserver < ActiveRecord::Observer
  def after_create(update)
    update.notify_contributors(update)
  end
end
