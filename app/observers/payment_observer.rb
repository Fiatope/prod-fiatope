class PaymentObserver < ActiveRecord::Observer
  observe :contribution, :match

  def after_create(resource)
    resource.define_key!
  end

  def before_save(resource)
    if resource.confirmed? && resource.confirmed_at.nil?
      if resource.is_a? Contribution
        unless resource.payment_method == 'PrePopulate'
          notify_confirmation(resource)
        end
      else
        notify_confirmation(resource)
      end
    end
  end

  def from_confirmed_to_canceled(resource)
    resource.notify_owner(:contribution_failed_generic)
    notification_for_backoffice(resource, :payment_canceled_after_confirmed)
  end

  def from_confirmed_to_requested_refund(resource)
    notification_for_backoffice(resource, :refund_request)
  end

  private

  def notify_confirmation(resource)
    resource.update(confirmed_at: Time.now)
    unless resource.payment_method.in?(["Orange Money", "Stripe"])
      resource.notify_owner(:payment_confirmed,
                            { },
                            { project: resource.project,
                              bcc: Configuration[:email_payments] })
      resource.project.notify_owner(:project_owner_contribution_confirmed)
    end

    if resource.project.expires_at < 7.days.ago
      notification_for_backoffice(resource, :payment_confirmed_after_finished_project)
    end
  end

  def notification_for_backoffice(resource, template_name, options = {})
    user = User.find_by(email: Configuration[:email_payments])

    if user
      key = resource.class.model_name.param_key
      Notification.notify_once(template_name,
                               user,
                               { "#{key}_id".to_sym => resource.id },
                               {  key.to_sym        => resource }.merge(options)
      )
    end
  end
end
