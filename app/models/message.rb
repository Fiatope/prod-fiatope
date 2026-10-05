class Message  
  extend ActiveModel::Naming  
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include ActionView::Helpers::TextHelper

  attr_accessor :name, :email, :subject, :message, :type
   
  validates :name,
            :presence => true 

   validates :subject,
            :presence => true

  validates :email,
            :format => { :with => /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/ }

  validates :message,
            :length => { :minimum => 10, :maximum => 1000 }

  def initialize(attributes = {})
    # puts "================ attributes : #{attributes} ==========="

    attributes.each do |name, value|
     send("#{name}=", value)
    end  
  end

  def deliver
    return false unless valid?

    # Pony.mail({
    #   :from => %("#{name}" <#{'contact@fiatope.com'}>),
    #   :reply_to => email,
    #   :subject => subject,
    #   :body => message,
    #   :html_body => simple_format(message)
    # })

    Pony.mail({
      :from => %("#{name}" <#{'contact@fiatope.com'}>),
      :to => email,
      :subject => subject,
      :body => message,
      :html_body => simple_format(message),
      :via => :smtp,
      :via_options => {
        # Ancienne configuration SendGrid (compte suspendu) - conservee pour memoire
        # :address              => Configuration[:SENDGRID_ADDRESS],
        # :port                 => Configuration[:SENDGRID_PORT],
        # :user_name            => Configuration[:SENDGRID_USERNAME],
        # :password             => Configuration[:SENDGRID_PASSWORD],
        :address              => Configuration[:SMTP_ADDRESS],
        :port                 => Configuration[:SMTP_PORT] || 587,
        :enable_starttls_auto => true,
        :user_name            => Configuration[:SMTP_USERNAME],
        :password             => Configuration[:SMTP_PASSWORD],
        :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
        :domain               => Configuration[:SMTP_DOMAIN] || "fiatope.com", # the HELO domain provided by the client to the server
        :arguments => ''
      }
    })

  end

  def persisted?
   false  
  end
end 

