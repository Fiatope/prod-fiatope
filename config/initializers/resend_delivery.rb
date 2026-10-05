# Transport email via l'API HTTP Resend (https://resend.com).
# Necessaire car le VPS de production bloque les ports SMTP sortants (25/465/587).
# Activation : definir RESEND_API_KEY en variable d'environnement (voir
# config/initializers/mail_config.rb). Sans cette variable, l'app reste en SMTP.
require 'net/http'
require 'json'

class ResendDelivery
  attr_accessor :settings

  def initialize(_settings = {})
    @settings = _settings || {}
  end

  def deliver!(mail)
    payload = {
      from: mail[:from].formatted.first,
      to: Array(mail.to),
      subject: mail.subject
    }
    if mail.multipart?
      html = mail.html_part&.body&.decoded
      text = mail.text_part&.body&.decoded
    elsif mail.mime_type == 'text/html'
      html = mail.body.decoded
      text = nil
    else
      html = nil
      text = mail.body.decoded
    end
    if html
      payload[:html] = html
      payload[:text] = text if text
    else
      payload[:text] = text
    end
    payload[:reply_to] = Array(mail.reply_to) if Array(mail.reply_to).any?
    payload[:cc] = Array(mail.cc) if Array(mail.cc).any?
    payload[:bcc] = Array(mail.bcc) if Array(mail.bcc).any?
    if mail.attachments.any?
      payload[:attachments] = mail.attachments.map do |a|
        { filename: a.filename, content: [a.body.decoded].pack('m0') }
      end
    end

    uri = URI('https://api.resend.com/emails')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{ENV['RESEND_API_KEY']}"
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Resend delivery failed (HTTP #{response.code}): #{response.body}"
    end

    response
  end
end

ActionMailer::Base.add_delivery_method :resend, ResendDelivery
