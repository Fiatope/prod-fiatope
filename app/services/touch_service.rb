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
        @country = country
        @operator = operator
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

        @uri = URI.parse(@touch_host)
        @username = @touch_username
        @password = @touch_password
    end

    def request path=nil, data=nil, digest=false
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

            req.basic_auth(@username, @password)
        end

        http.request(req)
    end

    def initiate_paiement
        return config_error_response unless valid_touch_config?

        id_client = "#{Time.now.to_i}#{@contribution.id}"

        @contribution.cfa_value = (@contribution.value * conversion_rate).round

        data = {
            'idFromClient' => id_client,
            'additionnalInfos': {
                'recipientEmail' => @contribution.user.email,
                'recipientFirstName' => @contribution.user.name,
                'recipientLastName' => @contribution.user.name,
                'destinataire' => @phone
            },
            'amount': @contribution.cfa_value.to_i,
            'callback' => @url_callback,
            'recipientNumber' => @phone,
            'serviceCode' => @touch_servicecode
        }

        Rails.logger.info("[TouchService] initiating payment country=#{@country} operator=#{@operator} path_id=#{@touch_path_id} login_api=#{masked_value(@touch_login_api)} service_code=#{@touch_servicecode}")

        response = request("/dist/api/touchpayapi/v1/#{@touch_path_id}/transaction", data, true)
        JSON.parse(response.body)
    rescue StandardError => e
        Rails.logger.error("[TouchService] initiate_paiement failed: #{e.message}")
        {
            'status' => 'CONFIG_ERROR',
            'message' => 'Touch configuration error',
            'detailMessage' => e.message
        }
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

        response = request("/v1/#{@touch_path_id}/check_status", data, true)
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
        ENV['CFA_CONVERSION_RATE'].to_f || 656
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
