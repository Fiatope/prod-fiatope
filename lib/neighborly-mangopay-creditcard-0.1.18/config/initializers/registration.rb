begin
  PaymentEngine.new(Neighborly::Mangopay::Creditcard::Interface.new).save
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
