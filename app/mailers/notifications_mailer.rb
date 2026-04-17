class NotificationsMailer < ActionMailer::Base
  layout 'email'

  def project_created_partner(project)
    @project = project
    partner = Partner.find(project.partner_id)
    if partner.has_attribute?(:email)
      mail(from: display_from(ENV['EMAIL_SYSTEM']), to: partner.email, subject: "Nouveau projet créé")
    end
  end

  def project_created(project)
    @project = project
    mail(from: display_from(ENV['EMAIL_SYSTEM']), to: ENV['EMAIL_SYSTEM'], subject: "Un nouveau projet a été soumis")
  end

  def notify(notification)
    @notification = notification
    address = Mail::Address.new @notification.origin_email
    address.display_name = @notification.origin_name
    subject = render_to_string(template: "notifications_mailer/subjects/#{@notification.template_name}.#{@notification.locale}")

    params = {
      from: address.format,
      to: @notification.user.email,
      subject: subject,
      template_name: @notification.template_name
    }

    params.merge!({ bcc: @notification.bcc }) if @notification.bcc.present?

    m = nil
    I18n.with_locale(@notification.locale) do
      m = mail(params)
    end
    m
  end

  private

  def display_from(addr = nil)
    addr ||= ENV['EMAIL_CONTACT'] || 'contact@fiatope.com'
    "Fiatope <#{addr}>"
  end

end
