class RegistrationsController < Devise::RegistrationsController
    prepend_before_action :check_captcha, only: [:create] # Change this to be any actions you want to protect.
  
    private
      def check_captcha
        if ENV['RAILS_ENV'] == "production"
          unless verify_recaptcha
            puts verify_recaptcha
            self.resource = resource_class.new sign_up_params
            # resource.validate # Look for any other validation errors besides reCAPTCHA
            # set_minimum_password_length
            respond_with_navigational(resource) { render :new }
          end 
        else
          self.resource = resource_class.new sign_up_params
          # respond_with_navigational(resource) { render :new }
        end
      end
  end