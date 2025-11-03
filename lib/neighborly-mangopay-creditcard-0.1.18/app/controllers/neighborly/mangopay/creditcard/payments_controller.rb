module Neighborly::Mangopay::Creditcard
  class PaymentsController < ActionController::Base
    before_action :authenticate_user!

    def new
      @mangopay_contributor = current_user.mangopay_contributor

      @cards = []
      current_user.registered_cards_with_currency(params[:currency]).each do |rc|
        begin
          hash = ::MangoPay::Card.fetch(rc.key)
          hash["kwendoo_id"] = rc.id
          @cards << RecursiveOpenStruct.new(hash)
        rescue MangoPay::ResponseError => ex
          if ex.code.to_i == 404
            rc.destroy
          end
          puts "==================================================="
          puts "========MANGOPAY CARD CHECK HAS FAILED=============="
          puts "============= SEE RESCUE FOR MORE INFO ==========="
          puts "==================================================="
          puts "==================================================="
          puts ex.details
        end
      end
      begin
        # ici on créé une CardRegistration et on récupère le PreRegistrationData , CardRegistrationURL and AccessKey
        @new_card_request = RecursiveOpenStruct.new(
                              ::MangoPay::CardRegistration.create({
                                UserId: @mangopay_contributor.key,
                                Currency: params[:currency],
                                Tag: 'Test Card Registration'
                              })
                            )
        puts "==================================================="
        puts "===========MANGOPAY CARD REGISTRATION HAS SUCCEEDED==="
        puts "================ #{@new_card_request} ==========="
        puts "==================================================="
        puts "==================================================="
      rescue MangoPay::ResponseError => ex
        puts "==================================================="
        puts "================MANGOPAY CARD REGISTRATION HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end
    end

    def delete
      card = Neighborly::Mangopay::RegisteredCard.find_by_id(params[:id])
      render json: { success: false } and return false unless card.user == current_user
      card.destroy!
      render json: { success: true, card_id: params[:id] }
    end

    def ip_address
      request.remote_ip
    end

    def browser_info
      latitude = request.location&.latitude
      longitude = request.location&.longitude
      timezone_offset = '+0'

      unless latitude.nil? && longitude.nil?
        timezone = Timezone.lookup(latitude, longitude)
        puts "================ timezone name : #{timezone.name} ==========="
        timezone_offset = Time.now.in_time_zone(timezone.name).formatted_offset.to_s.split(':')[0]
      end

      puts "================ timezone offset : #{timezone_offset} ==========="

      {
        "UserAgent" => request.headers["HTTP_USER_AGENT"],
        "AcceptHeader" => request.headers["HTTP_ACCEPT"],
        "Language" => request.headers["HTTP_ACCEPT_LANGUAGE"].scan(/^[a-z]{2}/).first,
        "JavaEnabled" => true,
        "ColorDepth" => 4,
        "ScreenHeight" => 1800,
        "ScreenWidth" => 400, 
        "TimeZoneOffset" => timezone_offset,
        "JavascriptEnabled" => true,
      }
    end

    def create
      checkout_hash = resource_params # contribution

      ip_address_hash = Hash.new
      ip_address_hash[:ip_address] = ip_address
      checkout_hash = checkout_hash.merge(ip_address_hash)

      browser_info_hash = Hash.new
      browser_info_hash[:browser_info] = browser_info
      checkout_hash = checkout_hash.merge(browser_info_hash)

      # puts "================ ip_address : #{checkout_hash[:ip_address]} ==========="
      # puts "================ browser_info : #{checkout_hash[:browser_info]} ==========="

      if checkout_hash.fetch(:use_card).present? && checkout_hash.fetch(:use_card) != "new"
        checkout_hash[:card_key] = checkout_hash.fetch(:use_card)
      else
        checkout_hash[:card_key] = attach_card_to_customer
      end

      session[:card_key] = checkout_hash[:card_key]

      return_url = secured_return_url(resource.id)
      payment = Payment.new('mangopay-creditcard',
                            current_user.mangopay_contributor,
                             resource,
                             return_url,
                             checkout_hash)
      begin
        debit = payment.debit!
        puts "==================================================="
        puts "===========MANGOPAY PAYMENT HAS SUCCEEDED==="
        puts "================ #{debit} ==========="
        puts "==================================================="
        puts "==================================================="
      rescue MangoPay::ResponseError => ex
        resource.cancel! unless resource.state == "canceled"
        puts "==================================================="
        puts "================MANGOPAY PAYMENT HAS FAILED==="
        puts "================ SEE RESCUE FOR MORE INFO ==========="
        puts "==================================================="
        puts "==================================================="
        puts ex.details
      end

      puts "======================mangopay/creditcard/payments_controller.rb#48===================================="
       puts debit.to_json
      puts "======================================================================================================="

      if debit.try(:Status) == "SUCCEEDED"
        payment.checkout!
        redirect_to(*checkout_response_params(resource, payment.successful?))
      else
        resource.update!(
          payment_id:                       debit.try(:Id),
          payment_method:                   'mangopay-creditcard',
          payment_service_fee:              0,
          payment_service_fee_paid_by_user: false,
          response_code: debit.try(:ResultCode),
          response_message: debit.try(:ResultMessage)
        )

        if debit.try(:SecureModeNeeded) && debit.try(:SecureModeRedirectURL).present?
          redirect_to debit.SecureModeRedirectURL and return
        else
          resource.cancel! unless resource.state == "canceled"
          if debit.try(:ResultCode) == "001011" # transaction amount is higher than max permitted
            flash.alert = t('neighborly.mangopay.creditcard.payments.confirm_secured_payment.errors.transaction_overall')
            resource.notify_owner(:contribution_failed_over_limit)
            redirect_to main_app.mangopay_authentications_user_path(current_user)
          elsif debit.try(:ResultCode) == "101410" # Card invalid
            current_user.registered_cards.where(key: debit.try(:CardId)).first.delete
            resource.notify_owner(:contribution_failed_wrong_card_format)
            redirect_to(*checkout_response_params(resource, false, t('neighborly.mangopay.creditcard.payments.confirm_secured_payment.errors.card_invalid')))
          elsif ["101399", "101304", "101303", "101302", "101301"].include?(debit.try(:ResultCode)) # 3DS Failed
            resource.notify_owner(:contribution_failed_3DSecure_failed)
            redirect_to(*checkout_response_params(resource, false, t('neighborly.mangopay.creditcard.payments.confirm_secured_payment.errors.3ds_failed')))
          else
            resource.notify_owner(:contribution_failed_generic)
            redirect_to(*checkout_response_params(resource, false))
          end
        end
      end
    end

    def confirm_secured_payment
      resource_from_3d_secure.update!(
        payment_id:                       MangoPay::PayIn.fetch(params[:transactionId])['Id'],
        payment_method:                   'mangopay-creditcard',
        payment_service_fee:              0,
        payment_service_fee_paid_by_user: false,
        response_code: MangoPay::PayIn.fetch(params[:transactionId])['ResultCode'],
        response_message: MangoPay::PayIn.fetch(params[:transactionId])['ResultMessage']
      )

      if params[:transactionId] != resource_from_3d_secure.payment_id
        resource_from_3d_secure.cancel
        resource_from_3d_secure.notify_owner(:contribution_failed_3DSecure_failed)
        redirect_to(*checkout_response_params(resource_from_3d_secure, false))
      elsif MangoPay::PayIn.fetch(params[:transactionId])['ResultCode'] == '000000'
        resource_from_3d_secure.confirm!
        redirect_to(*checkout_response_params(resource_from_3d_secure, true))
      else
        resource_from_3d_secure.notify_owner(:contribution_failed_3DSecure_failed)
        resource_from_3d_secure.cancel
        redirect_to(*checkout_response_params(resource_from_3d_secure, false))
      end
    end

    private
    def resource
      @resource ||= if params[:payment][:match_id].present?
                      Match.find(params[:payment].fetch(:match_id))
                    else
                      Contribution.find(params[:payment].fetch(:contribution_id))
                    end
    end

    def resource_from_3d_secure
      @resource ||= if params[:match_id].present?
                      Match.find(params[:match_id])
                    else
                      Contribution.find(params[:contribution_id])
                    end
    end

    def delete_registered_card(card_key)
      card = Neighborly::Mangopay::RegisteredCard.find_by_key(card_key)
      card.destroy! unless card.nil?
    end

    def resource_name
      resource.class.model_name.singular.to_sym
    end

    def checkout_response_params(resource, success, custom_error = nil)
      status = success ? :succeeded : :failed
      custom_error = resource.response_message if status == :failed
      inner_error = custom_error.present? ? "#{t('.errors.default')} (#{custom_error}). Bien vouloir essayer à nouveau votre contribution" : "#{t('.errors.default')} Bien vouloir essayer à nouveau votre contribution"
      route_params = [resource.project.permalink, resource.id]

      delete_registered_card(session[:card_key]) if resource_name == :contribution && status == :failed

      {
        contribution: {
          succeeded: [
            main_app.project_contribution_path(*route_params)
          ],
          failed: [
            main_app.edit_project_contribution_path(*route_params),
            alert: inner_error
          ]
        },
        match: {
          succeeded: [
            main_app.project_match_path(*route_params)
          ],
          failed: [
            main_app.edit_project_match_path(*route_params),
            alert: inner_error
          ]
        }
      }.fetch(resource_name).fetch(status)
    end

    def resource_params
      params.require(:payment).
             permit(:contribution_id,
                    :match_id,
                    :use_card,
                    :pay_fee,
                    :card_number,
                    :security_code,
                    :expiration_month,
                    :expiration_year,
                    user: {})
    end

    def card_params
      params.permit(
        :access_key,
        :preregistration_data,
        :card_registration_url,
        :card_id
      )
    end

    # Return the card Id
    def attach_card_to_customer
      month_value = resource_params.fetch(:expiration_month).to_s
      month_formatted = month_value.length == 1 ? "0#{month_value}" : month_value

      data = {
        data: card_params.fetch(:preregistration_data),
        accessKeyRef: card_params.fetch(:access_key),
        cardNumber: resource_params.fetch(:card_number),
        cardExpirationDate: month_formatted + resource_params.fetch(:expiration_year).to_s[2..4],
        cardCvx: resource_params.fetch(:security_code)
      }
      res = Net::HTTP.post_form(URI(card_params.fetch(:card_registration_url)), data)
      unless (res.is_a?(Net::HTTPOK) && res.body.start_with?('data='))
        # raise Exception, [res, res.body] 
        current_user.contributions.last.notify_owner(:contribution_failed_generic)
        return
      end


      final_card_info = ::RecursiveOpenStruct.new(::MangoPay::CardRegistration.update(card_params.fetch(:card_id), {
                            RegistrationData: res.body
                          })
                        )
      current_user.registered_cards.create!(key: final_card_info.try(:CardId), currency: final_card_info.try(:Currency))
      return final_card_info.try(:CardId)
    end

    def customer
      @customer ||= ::RecursiveOpenStruct.new(Neighborly::Mangopay::Customer.new(current_user, params).fetch)
    end

    def update_customer
      Neighborly::Mangopay::Customer.new(current_user, params).update!
    end
  end
end
