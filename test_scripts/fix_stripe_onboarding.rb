# ============================================================
# 🔧 FIX: Génère un lien d'onboarding Stripe pour compléter le compte
# ============================================================

puts "\n" + "=" * 70
puts "🔧 FIX STRIPE ONBOARDING - FIATOPE"
puts "=" * 70

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

# Trouver le porteur avec onboarding incomplet
porteur = User.where.not(stripe_connect_account_id: [nil, ''])
              .where(stripe_onboarding_complete: [false, nil]).first

if porteur.nil?
  # Chercher un compte avec charges_enabled = false
  User.where.not(stripe_connect_account_id: [nil, '']).each do |u|
    begin
      account = Stripe::Account.retrieve(u.stripe_connect_account_id)
      unless account.charges_enabled && account.payouts_enabled
        porteur = u
        break
      end
    rescue Stripe::StripeError => e
      puts "Erreur pour #{u.email}: #{e.message}"
    end
  end
end

if porteur.nil?
  puts "✅ Tous les porteurs ont complété leur onboarding Stripe!"
  exit 0
end

puts "\n📋 Porteur avec onboarding incomplet:"
puts "   Email: #{porteur.email}"
puts "   Stripe Account: #{porteur.stripe_connect_account_id}"

# Vérifier l'état actuel
begin
  account = Stripe::Account.retrieve(porteur.stripe_connect_account_id)
  puts "\n📊 État du compte Stripe:"
  puts "   Type: #{account.type}"
  puts "   Country: #{account.country}"
  puts "   Charges enabled: #{account.charges_enabled ? '✅' : '❌'}"
  puts "   Payouts enabled: #{account.payouts_enabled ? '✅' : '❌'}"
  puts "   Details submitted: #{account.details_submitted ? '✅' : '❌'}"
  
  if account.requirements&.currently_due&.any?
    puts "\n⚠️ Informations requises:"
    account.requirements.currently_due.each do |req|
      puts "   • #{req}"
    end
  end
  
  if account.requirements&.errors&.any?
    puts "\n❌ Erreurs:"
    account.requirements.errors.each do |err|
      puts "   • #{err.code}: #{err.reason}"
    end
  end
  
  # Générer un lien d'onboarding
  puts "\n" + "-" * 70
  puts "🔗 GÉNÉRATION DU LIEN D'ONBOARDING"
  puts "-" * 70
  
  account_link = Stripe::AccountLink.create({
    account: porteur.stripe_connect_account_id,
    refresh_url: "http://localhost:3000/stripe/connect/refresh",
    return_url: "http://localhost:3000/stripe/connect/return",
    type: 'account_onboarding'
  })
  
  puts "\n🎯 LIEN D'ONBOARDING (valide 24h):"
  puts "\n   #{account_link.url}"
  puts "\n" + "=" * 70
  puts "📝 INSTRUCTIONS:"
  puts "   1. Copiez le lien ci-dessus"
  puts "   2. Ouvrez-le dans un navigateur"
  puts "   3. Complétez toutes les informations demandées"
  puts "   4. Une fois terminé, relancez les tests"
  puts "=" * 70
  
rescue Stripe::StripeError => e
  puts "❌ Erreur Stripe: #{e.message}"
end
