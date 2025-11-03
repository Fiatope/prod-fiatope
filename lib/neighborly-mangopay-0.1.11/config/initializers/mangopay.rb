MangoPay.configure do |c|
  begin
    # c.preproduction     = Rails.env.development? || Rails.env.test?
    c.preproduction     = ENV['MANGOPAY_PREPRODUCTION'].downcase == 'true' ? true : false
    c.client_id         = ENV['MANGOPAY_CLIENT_ID']
    c.client_apiKey     = ENV['MANGOPAY_CLIENT_PASSPHRASE']
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "MangoPay has been correctly initialized with following parameters"
    puts "client_id = #{c.client_id}"
    puts "client_apiKey = #{c.client_apiKey}"
    puts "preproduction = #{c.preproduction}"
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
    puts "=================================================================="
  rescue StandardError
    puts "Error in initialization Mangopay : #{StandardError}"
  end


end
