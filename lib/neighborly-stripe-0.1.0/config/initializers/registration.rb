# Enregistrer Stripe dans PaymentEngine au démarrage
begin
  PaymentEngine.new(Neighborly::Stripe::Interface.new).save
  puts "==> Stripe payment engine registered successfully"
rescue Exception => e
  puts "Error while registering Stripe payment engine: #{e}"
end
