# TEST CALCULS COMMISSION STRIPE - FIATOPE
puts "=" * 60
puts "💰 TEST CALCULS COMMISSION STRIPE - FIATOPE"
puts "=" * 60

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

platform_fee_percent = ENV.fetch('PLATFORM_FEE', '5.0').to_f
puts "\n📊 Commission plateforme: #{platform_fee_percent}%"
puts "📊 Commission Stripe: 1.4% + 0.25€ (Cartes EU)"

test_amounts = [10, 25, 50, 100, 250, 500, 1000]
errors = []

puts "\n" + "-" * 60
puts "| Montant | Stripe Fee | Platform Fee | Net Porteur | Vérifié |"
puts "-" * 60

test_amounts.each do |amount|
  begin
    calc = Neighborly::Stripe::FeeCalculator.new(amount)
    
    stripe_fee = calc.gateway_fee
    platform_fee = calc.platform_fee
    net_amount = amount - stripe_fee - platform_fee
    
    # Vérification manuelle (1.4% + 0.25€ pour cartes EU)
    expected_stripe = (amount * 0.014 + 0.25).round(2)
    expected_platform = (amount * platform_fee_percent / 100).round(2)
    
    stripe_ok = (stripe_fee - expected_stripe).abs < 0.01
    platform_ok = (platform_fee - expected_platform).abs < 0.01
    
    status = stripe_ok && platform_ok ? "✅" : "❌"
    
    puts "| #{amount.to_s.rjust(7)}€ | #{stripe_fee.to_s.rjust(10)}€ | #{platform_fee.to_s.rjust(12)}€ | #{net_amount.round(2).to_s.rjust(11)}€ | #{status.center(7)} |"
    
    unless stripe_ok && platform_ok
      errors << "Montant #{amount}€: Stripe=#{stripe_fee} (attendu: #{expected_stripe}), Platform=#{platform_fee} (attendu: #{expected_platform})"
    end
  rescue => e
    puts "| #{amount.to_s.rjust(7)}€ | ERREUR: #{e.message}"
    errors << "Montant #{amount}€: #{e.message}"
  end
end

puts "-" * 60

# Test avec contribution réelle
puts "\n📋 TEST AVEC CONTRIBUTION RÉELLE"
puts "-" * 60

contribution = Contribution.where(payment_method: 'Stripe').order(created_at: :desc).first
if contribution
  amount = contribution.value.to_f
  calc = Neighborly::Stripe::FeeCalculator.new(amount)
  
  puts "  Contribution ##{contribution.id}"
  puts "  Montant: #{amount}€"
  puts "  Frais Stripe: #{calc.gateway_fee}€"
  puts "  Commission plateforme: #{calc.platform_fee}€"
  puts "  Net porteur: #{(amount - calc.gateway_fee - calc.platform_fee).round(2)}€"
  
  if contribution.stripe_charge_id.present?
    begin
      charge = Stripe::Charge.retrieve(contribution.stripe_charge_id)
      actual_fee = charge.balance_transaction ? Stripe::BalanceTransaction.retrieve(charge.balance_transaction).fee / 100.0 : 0
      puts "  Frais Stripe réels: #{actual_fee}€"
    rescue => e
      puts "  ⚠️ Impossible de récupérer frais réels: #{e.message}"
    end
  end
else
  puts "  ⚠️ Aucune contribution Stripe trouvée"
end

puts "\n" + "=" * 60
if errors.empty?
  puts "✅ TOUS LES CALCULS DE COMMISSION SONT CORRECTS"
else
  puts "❌ #{errors.count} erreur(s):"
  errors.each { |e| puts "   • #{e}" }
end
puts "=" * 60
