class ApplicationController < ActionController::Base
  include Concerns::ExceptionHandler
  include Concerns::SocialHelpersHandler
  include Concerns::PersistentWarnings
  include Concerns::AuthenticationHandler
  include Pundit
  # include Pundit::Authorization
  # skip_before_action  :verify_authenticity_token
  protect_from_forgery prepend: true, with: :exception

  helper_method :channel, :referral_url, :available_currencies
  
  before_action :store_user_location!, if: :storable_location?
  before_action :referral_it!

  before_action :set_locale unless Rails.env.test?

  before_action :configure_permitted_parameters, if: :devise_controller?
 
  before_action do
    if current_user and (current_user.email =~ /change-your-email\+[0-9]+@neighbor\.ly/)
      redirect_to set_email_users_path unless controller_name =~ /users|confirmations/
    end
  end

  after_action do
    if controller_name != "build" && cookies[:new_project_partner_id].present?
      cookies.delete(:new_project_partner_id)
    end
  end

  def after_sign_in_path_for(resource)
    puts "resource"
    puts resource
    puts "resource"
      
    stored_location_for(resource) || root_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email, :birthday, :password, :password_confirmation])
  end

  def channel
    Channel.find_by_permalink(request.subdomain.to_s)
  end

  def referral_url
    session[:referral_url]
  end

  def available_currencies
    ::Configuration.fetch('currency').split(',')
  end

  private

  # Its important that the location is NOT stored if:
  # - The request method is not GET (non idempotent)
  # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an 
  #    infinite redirect loop.
  # - The request is an Ajax request as this can lead to very unexpected behaviour.
  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr? 
  end

  def store_user_location!
    # :user is the scope we are authenticating
    store_location_for(:user, request.fullpath)
  end

  def referral_it!
    session[:referral_url] = params[:ref] if params[:ref].present?
  end

  # def set_locale
  #   if params[:locale].present?
  #     I18n.locale = params[:locale].to_sym
  #   end
  # end

  def set_locale
    if current_user
      current_user_locale = params[:locale] || I18n.default_locale
      unless current_user.locale == current_user_locale
        current_user.update_attribute(:locale, current_user_locale)
      end
    end

    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options(options={})
    { :locale => I18n.locale == I18n.default_locale ? nil : I18n.locale  }
  end

  def verify_authenticity_token
    request.headers['X-CSRF-Token'] ||= request.headers['X-XSRF-TOKEN']
    super
  end

end
