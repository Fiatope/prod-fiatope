class TouchService < ApplicationService
    include Rails.application.routes.url_helpers

    attr_accessor :country, :operator, :phone, :contribution, :url_callback,
                    :touch_host, :touch_path_id, :touch_partner_id,
                    :touch_login_api, :touch_password_api, :touch_username,
                    :touch_password, :touch_servicecode,
                    :uri, :username, :password

    LIST_OPERATORS = {
        'Cameroun' => {
            'CM_MTN' => 'MTN (Cameroun)',
            'CM_OM' => 'Orange (Cameroun)'
            # 'CM_YUP' => 'YUP (Cameroun)'
        },
        'Côte d\'Ivoire' => {
            'CI_MV' => 'MOOV (Côte d\'Ivoire)',
            'CI_MTN' => 'MTN (Côte d\'Ivoire)',
            'CI_OM' => 'Orange (Côte d\'Ivoire)'
            # 'CI_WZ' => 'Wizall (Côte d\'Ivoire)'
        },
        'Guinée' => {
            'GN_MTN' => 'MTN (Guinée)',
            'GN_OM' => 'Orange (Guinée)'
        },
        'Sénégal' => {
            'SN_EM' => 'Emoney (Sénégal)',
            'SN_FM' => 'Free Money (Sénégal)',
            'SN_OM' => 'Orange (Sénégal)'
            # 'SN_WZ' => 'Wizall (Sénégal)'
        }
    }

    def initialize country=nil, operator=nil, phone=nil, contribution=nil
        @country = country.to_s
        @operator = operator.to_s
        @phone = phone
        @contribution = contribution
        @url_callback = touch_payment_return_project_contribution_url(contribution.project, contribution) if contribution.present?

        @touch_host = env_value('TOUCH_HOST')
        @touch_path_id = env_value('TOUCH_' + @country + '_PATH_ID')
        @touch_partner_id = env_value('TOUCH_' + @country + '_' + @operator + '_PARTNER_ID')
        @touch_login_api = env_value('TOUCH_' + @country + '_' + @operator + '_LOGIN_API')
        @touch_password_api = env_value('TOUCH_' + @country + '_' + @operator + '_PASSWORD_API')
        @touch_username = env_value('TOUCH_' + @country + '_' + @operator + '_USERNAME')
        @touch_password = env_value('TOUCH_' + @country + '_' + @operator + '_PASSWORD')
        @touch_servicecode = env_value('TOUCH_' + @country + '_' + @operator + '_SERVICECODE')

        @uri = URI.parse(@touch_host) if @touch_host.present?
        @username = @touch_username
        @password = @touch_password
    end

    def request path=nil, data=nil, digest=false, no_http_auth=false
        req = nil
        http = nil

        if digest
            raise 'Touch host missing' if @touch_host.blank?

            query = URI.encode_www_form(
                loginAgent: @touch_login_api,
                passwordAgent: @touch_password_api
            )
            digest_url = "#{normalized_host}#{path}?#{query}"
            @digest_uri = URI.parse(digest_url) if path
            @digest_uri.user = @username
            @digest_uri.password = @password

            http = Net::HTTP.new(@digest_uri.host, @digest_uri.port)
            http.use_ssl = @digest_uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE

            Rails.logger.info("[TouchService] digest request url=#{masked_touch_url(@digest_uri)}")

            req = Net::HTTP::Get.new(@digest_uri.request_uri)
            req['Accept'] = 'application/json'
            req['Content-Type'] = 'application/json'

            response = http.request(req)

            auth = nil

            digest_auth = Net::HTTP::DigestAuth.new

            if data
                auth = digest_auth.auth_header @digest_uri, response['www-authenticate'], 'PUT'
                req = Net::HTTP::Put.new(@digest_uri.request_uri)
                req.body = data.to_json
            else
                auth = digest_auth.auth_header @digest_uri, response['www-authenticate'], 'GET'
                req = Net::HTTP::Get.new(@digest_uri.request_uri)
            end

            req['Accept'] = 'application/json'
            req['Content-Type'] = 'application/json'

            req.add_field 'Authorization', auth
        else
            request_uri = URI.parse("#{normalized_host}#{path}") if path

            http = Net::HTTP.new(request_uri.host, request_uri.port)
            http.use_ssl = request_uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE

            Rails.logger.info("[TouchService] basic request url=#{masked_touch_url(request_uri)}")

            if data
                req = Net::HTTP::Post.new(request_uri.request_uri)
                req.body = data.to_json
            else
                req = Net::HTTP::Get.new(request_uri.request_uri)
            end

            req['Accept'] = 'application/json'
            req['Content-Type'] = 'application/json'

            req.basic_auth(@username, @password) unless no_http_auth
        end

        http.request(req)
    end

    # Currency by country (XOF = CFA Ouest, XAF = CFA Centrale, GNF = Guinée)
    CURRENCY_BY_COUNTRY = {
        'SN' => 'XOF',
        'CI' => 'XOF',
        'CM' => 'XAF',
        'GN' => 'GNF'
    }.freeze

    def initiate_paiement
        return config_error_response unless valid_touch_config?

        id_client = "#{Time.now.to_i}#{@contribution.id}"

        # For XOF/XAF/GNF projects, value is already in the local currency — no EUR conversion needed.
        # Only multiply by conversion_rate for EUR (or other non-CFA) projects.
        project_currency = @contribution.project.try(:currency).to_s.strip.upcase
        @contribution.cfa_value =
            if %w[XOF XAF GNF FCFA].include?(project_currency)
                @contribution.value.to_i
            else
                (@contribution.value * conversion_rate).round
            end

        # return_url / cancel_url: used by OM app to redirect back after QR code payment
        success_url = touch_payment_return_project_contribution_url(@contribution.project, @contribution)
        cancel_url  = edit_project_contribution_url(project_id: @contribution.project, id: @contribution)

        # partner_name: displayed to the payer in the Orange Money app as the recipient merchant
        partner_name = @contribution.project.try(:name).presence || (defined?(Configuration) && Configuration[:company_name].presence) || 'Fiatope'

        # Per InTouch official spec (verified 2026-04-27):
        # recipientNumber = payer's phone number for ALL service codes
        # (PAIEMENTMARCHANDOMQRCODE, SNPAIEMENTWAVE, PAIEMENTMARCHANDTIGO, SN_INIT_PAIEMENT_TP, etc.)
        # Both recipientNumber and destinataire must be the customer who is paying.
        recipient_number = @phone

        additionnal_infos = {
            'recipientEmail'     => @contribution.user.email,
            'recipientFirstName' => @contribution.user.name,
            'recipientLastName'  => @contribution.user.name,
            'destinataire'       => @phone,
            'partner_name'       => partner_name,
            'return_url'         => success_url,
            'cancel_url'         => cancel_url
        }
        currency = CURRENCY_BY_COUNTRY[@country]
        additionnal_infos['currency'] = currency if currency.present?

        data = {
            'idFromClient' => id_client,
            'additionnalInfos': additionnal_infos,
            'amount': @contribution.cfa_value.to_i,
            'callback' => @url_callback,
            'recipientNumber' => recipient_number,
            'serviceCode' => @touch_servicecode
        }

        Rails.logger.info("[TouchService] initiating payment country=#{@country} operator=#{@operator} path_id=#{@touch_path_id} login_api=#{masked_value(@touch_login_api)} service_code=#{@touch_servicecode} currency=#{currency || 'none'} amount=#{@contribution.cfa_value.to_i} recipient_number=#{@phone} callback_url=#{@url_callback}")

        response = request("/dist/api/touchpayapi/v1/#{@touch_path_id}/transaction", data, true)
        parsed = JSON.parse(response.body)
        Rails.logger.info("[TouchService] initiate_paiement http_status=#{response.code} response_status=#{parsed['status']} id_from_client=#{parsed['idFromClient']} response_keys=#{parsed.keys.inspect} qr_present=#{self.class.qr_code_from(parsed).present?} om_link_present=#{parsed['OM'].present?} maxit_link_present=#{parsed['MAXIT'].present?} validity=#{parsed['validity']}")
        unless parsed['status'].to_s == 'INITIATED'
            Rails.logger.error("[TouchService] NON-INITIATED response: detail_message=#{parsed['detailMessage'].to_s.first(500)} stack_trace=#{parsed['stackTrace'].to_s.first(300)} suppressed=#{parsed['suppressedExceptions'].inspect}")
        end
        parsed
    rescue StandardError => e
        Rails.logger.error("[TouchService] initiate_paiement failed: #{e.class} #{e.message}")
        {
            'status' => 'CONFIG_ERROR',
            'message' => 'Touch configuration error',
            'detailMessage' => e.message
        }
    end

    # Defensive QR code accessor — tries several key variants returned by InTouch
    def self.qr_code_from(response)
        return nil unless response.is_a?(Hash)
        response['qrCode'] || response['qr_code'] || response['qrcode'] || response['QRCode'] || response['QR_CODE']
    end

    def check_status id_client
        return config_error_response unless valid_touch_config?

        data = {
            'partner_id' => @touch_partner_id,
            'partner_transaction_id' => id_client,
            'login_api' => @touch_login_api,
            'password_api' => @touch_password_api
        }

        Rails.logger.info("[TouchService] checking status country=#{@country} operator=#{@operator} id_client=#{id_client}")

        # Credentials are passed in the request body — no HTTP Basic auth header needed
        response = request("/v1/#{@touch_path_id}/check_status", data, false, true)
        JSON.parse(response.body)
    rescue StandardError => e
        Rails.logger.error("[TouchService] check_status failed: #{e.message}")
        {
            'status' => 'CONFIG_ERROR',
            'message' => 'Touch configuration error',
            'detailMessage' => e.message
        }
    end

    def conversion_rate
        rate = ENV['CFA_CONVERSION_RATE'].to_f
        rate > 0 ? rate : 656.0
    end

    private

    def env_value(key)
        value = ENV[key]
        return nil if value.blank?

        value = value.to_s.strip
        value = value.gsub(/\A['"]|['"]\z/, '')
        value.presence
    end

    def normalized_host
        @touch_host.to_s.sub(%r{/*\z}, '')
    end

    def valid_touch_config?
        required_values = {
            'TOUCH_HOST' => @touch_host,
            "TOUCH_#{@country}_PATH_ID" => @touch_path_id,
            "TOUCH_#{@country}_#{@operator}_LOGIN_API" => @touch_login_api,
            "TOUCH_#{@country}_#{@operator}_PASSWORD_API" => @touch_password_api,
            "TOUCH_#{@country}_#{@operator}_USERNAME" => @touch_username,
            "TOUCH_#{@country}_#{@operator}_PASSWORD" => @touch_password,
            "TOUCH_#{@country}_#{@operator}_SERVICECODE" => @touch_servicecode
        }

        missing_keys = required_values.select { |_, value| value.blank? }.keys
        return true if missing_keys.empty?

        Rails.logger.error("[TouchService] Missing touch configuration keys: #{missing_keys.join(', ')}")
        false
    end

    def config_error_response
        {
            'status' => 'CONFIG_ERROR',
            'message' => 'Touch configuration error',
            'detailMessage' => 'Missing or invalid Touch environment variables'
        }
    end

    def masked_value(value)
        str = value.to_s
        return '***' if str.length <= 4

        "#{str[0, 2]}***#{str[-2, 2]}"
    end

    def masked_touch_url(uri)
        url = uri.to_s
        url = url.gsub(/(passwordAgent=)[^&]+/, '\1***')
        url = url.gsub(%r{https://([^:]+):([^@]+)@}, 'https://***:***@')
        url
    end
end
