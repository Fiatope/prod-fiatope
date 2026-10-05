begin
  if Rails.env.production?
  ActionMailer::Base.default 'Content-Transfer-Encoding' => 'quoted-printable'

    ActionMailer::Base.delivery_method = :smtp

    ActionMailer::Base.smtp_settings = {
      address: Configuration[:SENDGRID_ADDRESS],
      port: Configuration[:SENDGRID_PORT],
      user_name: Configuration[:SENDGRID_USERNAME],
      password: Configuration[:SENDGRID_PASSWORD],
      authentication: :plain,
      domain: 'fiatope.com',
      open_timeout: 20,
      read_timeout: 20,
    }
  else
    config.mailer.delivery_method = :letter_opener
    config.mailer.perform_deliveries = true
  end
rescue => e
  Rails.logger.error("[MailConfig] Erreur de configuration SMTP: #{e.message}")
  Rollbar.error(e) if defined?(Rollbar)
end