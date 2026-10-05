begin
  if Rails.env.production?
  ActionMailer::Base.default 'Content-Transfer-Encoding' => 'quoted-printable'

    if ENV['RESEND_API_KEY'].present?
      # Les ports SMTP sortants sont bloques sur le VPS de production :
      # envoi via l'API HTTP de Resend (port 443).
      ActionMailer::Base.delivery_method = :resend
    else
      ActionMailer::Base.delivery_method = :smtp

    # Ancienne configuration SendGrid (compte suspendu) - conservee pour memoire
    # ActionMailer::Base.smtp_settings = {
    #   address: Configuration[:SENDGRID_ADDRESS],
    #   port: Configuration[:SENDGRID_PORT],
    #   user_name: Configuration[:SENDGRID_USERNAME],
    #   password: Configuration[:SENDGRID_PASSWORD],
    #   authentication: :plain,
    #   domain: 'fiatope.com',
    # }

    # SMTP generique configurable par variables d'environnement.
    # Gmail : SMTP_ADDRESS=smtp.gmail.com SMTP_PORT=587 SMTP_USERNAME=<compte google>
    #         SMTP_PASSWORD=<mot de passe d'application> SMTP_DOMAIN=fiatope.com
    ActionMailer::Base.smtp_settings = {
      address: Configuration[:SMTP_ADDRESS],
      port: Configuration[:SMTP_PORT] || 587,
      user_name: Configuration[:SMTP_USERNAME],
      password: Configuration[:SMTP_PASSWORD],
      authentication: :plain,
      enable_starttls_auto: true,
      domain: Configuration[:SMTP_DOMAIN] || 'fiatope.com',
      open_timeout: 20,
      read_timeout: 20,
    }
    end
  else
    config.mailer.delivery_method = :letter_opener
    config.mailer.perform_deliveries = true
  end
rescue => e
  Rails.logger.error("[MailConfig] Erreur de configuration SMTP: #{e.message}")
  Rollbar.error(e) if defined?(Rollbar)
end