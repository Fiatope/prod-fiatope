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

        @touch_host = ENV['TOUCH_HOST']
        @touch_path_id = ENV['TOUCH_' + @country + '_PATH_ID']
        @touch_partner_id = ENV['TOUCH_' + @country + '_' + @operator + '_PARTNER_ID']
        @touch_login_api = ENV['TOUCH_' + @country + '_' + @operator + '_LOGIN_API']
        @touch_password_api = ENV['TOUCH_' + @country + '_' + @operator + '_PASSWORD_API']
        @touch_username = ENV['TOUCH_' + @country + '_' + @operator + '_USERNAME']
        @touch_password = ENV['TOUCH_' + @country + '_' + @operator + '_PASSWORD']
        @touch_servicecode = ENV['TOUCH_' + @country + '_' + @operator + '_SERVICECODE']

        @uri = URI.parse(@touch_host)
        @username = @touch_username
        @password = @touch_password
    end

    def request path=nil, data=nil, digest=false
        req = nil
        http = nil

        if digest
            @digest_uri = URI.parse(@uri.to_s + path + "?loginAgent=#{@touch_login_api}&passwordAgent=#{@touch_password_api}") if path
            @digest_uri.user = @username
            @digest_uri.password = @password

            http = Net::HTTP.new(@digest_uri.host, @digest_uri.port)
            http.use_ssl = @digest_uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE

            puts "======================== url #{@digest_uri.to_s} ========================"

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
            @uri = URI.parse(@uri.to_s + path) if path

            http = Net::HTTP.new(@uri.host, @uri.port)
            http.use_ssl = @uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE

            puts "======================== url #{@uri.to_s} ========================"

            if data
                req = Net::HTTP::Post.new(@uri.request_uri)
                req.body = data.to_json
            else
                req = Net::HTTP::Get.new(@uri.request_uri)
            end

            req['Accept'] = 'application/json'
            req['Content-Type'] = 'application/json'

            req.basic_auth(@username, @password)
        end

        http.request(req)
    end

    def initiate_paiement
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
            'amount': @contribution.cfa_value,
            'callback' => @url_callback,
            'recipientNumber' => @phone,
            'serviceCode' => @touch_servicecode
        }

        puts "======================== data #{data} ========================"

        response = request("/dist/api/touchpayapi/v1/#{@touch_path_id}/transaction", data, true)
        JSON.parse(response.body)
    end

    def check_status id_client
        data = {
            'partner_id' => @touch_partner_id,
            'partner_transaction_id' => id_client,
            'login_api' => @touch_login_api,
            'password_api' => @touch_password_api
        }

        puts "======================== data #{data} ========================"

        response = request("/v1/#{@touch_path_id}/check_status", data)
        JSON.parse(response.body)
    end

    def conversion_rate
        ENV['CFA_CONVERSION_RATE'].to_f || 656
    end
end
