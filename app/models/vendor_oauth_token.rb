class VendorOauthToken < ActiveRecord::Base


  def self.get_access_token_for(provider_name)
    oauth_token = VendorOauthToken.find_by(provider_name: provider_name, expires_at: Date.tomorrow.end_of_day..Date.tomorrow.end_of_day + 3.years)
    if oauth_token
      oauth_token.access_token
    else
      generate_access_token_for(provider_name).access_token
    end
  end

  def self.generate_access_token_for(provider_name)
    generate_orange_money_token(provider_name)
  end

  def self.generate_orange_money_token(provider_name)
    header = case provider_name
    when "orange_money_cameroon"
      { "Authorization" => "Basic #{ENV['ORANGE_MONEY_AUTHORIZATION_HEADER_CAMEROON']}", "Content-Type" => "application/x-www-form-urlencoded" }
    when "orange_money_mali"
      { "Authorization" => "Basic #{ENV['ORANGE_MONEY_AUTHORIZATION_HEADER_MALI']}", "Content-Type" => "application/x-www-form-urlencoded" }
    else # "orange_money_default"
      { "Authorization" => "Basic #{ENV['ORANGE_MONEY_AUTHORIZATION_HEADER_DEFAULT']}", "Content-Type" => "application/x-www-form-urlencoded" }
    end

    uri = URI.parse(ENV['ORANGE_MONEY_OAUTH_URL'])

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.set_form_data("grant_type" => "client_credentials")

    puts "////////////////////request//////////////////////"
    puts request.inspect
    puts "///////////////////request///////////////////////"

    response = http.request(request)

    resp_json = JSON.parse(response.body)

    puts "//////////////////resp_json////////////////////////"
    puts resp_json.inspect
    puts "/////////////////resp_json/////////////////////////"

    token = resp_json["access_token"]
    expires_at = Time.at(Time.now.to_i + resp_json["expires_in"].to_i)

    create!(
      provider_name: provider_name,
      access_token: token,
      expires_at: expires_at,
      token_type: "Bearer"
    )
  end

end
