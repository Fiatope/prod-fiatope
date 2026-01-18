# DÉSACTIVÉ - MangoPay n'est plus utilisé (remplacé par Stripe)
# Pour réactiver, mettre MANGOPAY_ENABLED=true dans .env
if ENV['MANGOPAY_ENABLED']&.downcase == 'true'
  MangoPay.configure do |c|
    begin
      c.preproduction     = ENV['MANGOPAY_PREPRODUCTION'].downcase == 'true' ? true : false
      c.client_id         = ENV['MANGOPAY_CLIENT_ID']
      c.client_apiKey     = ENV['MANGOPAY_CLIENT_PASSPHRASE']
      puts "=================================================================="
      puts "MangoPay has been correctly initialized with following parameters"
      puts "client_id = #{c.client_id}"
      puts "client_apiKey = #{c.client_apiKey}"
      puts "preproduction = #{c.preproduction}"
      puts "=================================================================="
    rescue StandardError
      puts "Error in initialization Mangopay : #{StandardError}"
    end
  end
else
  puts "=================================================================="
  puts "MangoPay DÉSACTIVÉ - Utilisation de Stripe uniquement"
  puts "=================================================================="
end
