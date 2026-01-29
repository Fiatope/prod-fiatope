# ============================================================
# 🔱 TEST E2E 01 - API STRIPE RÉELLE
# ============================================================
# Teste les appels API Stripe réels
# ============================================================

puts "\n" + "=" * 70
puts "🔱 TEST E2E 01 - API STRIPE RÉELLE"
puts "=" * 70

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

errors = []
successes = []

# 1. Créer un PaymentIntent de test
puts "\n📋 1. CRÉATION PAYMENTINTENT TEST"
puts "-" * 50

begin
  payment_intent = Stripe::PaymentIntent.create({
    amount: 1000, # 10€ en centimes
    currency: 'eur',
    payment_method_types: ['card'],
    metadata: {
      test: 'true',
      platform: 'fiatope',
      created_by: 'e2e_test'
    }
  })
  
  if payment_intent.id.start_with?('pi_')
    successes << "PaymentIntent créé: #{payment_intent.id}"
    puts "  ✅ PaymentIntent créé: #{payment_intent.id}"
    puts "     Status: #{payment_intent.status}"
    puts "     Amount: #{payment_intent.amount / 100.0}€"
    
    # Annuler le PaymentIntent de test
    cancelled = Stripe::PaymentIntent.cancel(payment_intent.id)
    puts "  ✅ PaymentIntent annulé (nettoyage)"
  else
    errors << "PaymentIntent invalide"
  end
rescue Stripe::StripeError => e
  errors << "PaymentIntent: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 2. Créer une Checkout Session de test
puts "\n📋 2. CRÉATION CHECKOUT SESSION TEST"
puts "-" * 50

begin
  session = Stripe::Checkout::Session.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'eur',
        product_data: {
          name: 'Test Contribution Fiatope',
          description: 'Test E2E - Contribution crowdfunding'
        },
        unit_amount: 2500, # 25€
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: 'https://fiatope.com/success?session_id={CHECKOUT_SESSION_ID}',
    cancel_url: 'https://fiatope.com/cancel',
    metadata: {
      test: 'true',
      platform: 'fiatope',
      created_by: 'e2e_test'
    }
  })
  
  if session.id.start_with?('cs_')
    successes << "Checkout Session créée: #{session.id}"
    puts "  ✅ Checkout Session créée: #{session.id}"
    puts "     URL: #{session.url[0..60]}..."
    puts "     Status: #{session.status}"
    
    # Expirer la session (nettoyage)
    begin
      Stripe::Checkout::Session.expire(session.id)
      puts "  ✅ Session expirée (nettoyage)"
    rescue => e
      puts "  ⚠️ Session non expirable: #{e.message}"
    end
  else
    errors << "Checkout Session invalide"
  end
rescue Stripe::StripeError => e
  errors << "Checkout Session: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 3. Lister les comptes connectés
puts "\n📋 3. COMPTES CONNECTÉS"
puts "-" * 50

begin
  accounts = Stripe::Account.list(limit: 5)
  successes << "#{accounts.data.count} compte(s) connecté(s) trouvé(s)"
  puts "  ✅ #{accounts.data.count} compte(s) connecté(s)"
  
  accounts.data.each_with_index do |acc, i|
    puts "     #{i+1}. #{acc.id} (#{acc.type || 'N/A'})"
    puts "        Charges: #{acc.charges_enabled ? '✅' : '❌'} | Payouts: #{acc.payouts_enabled ? '✅' : '❌'}"
  end
rescue Stripe::StripeError => e
  errors << "Liste comptes: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 4. Vérifier les charges récentes
puts "\n📋 4. CHARGES RÉCENTES"
puts "-" * 50

begin
  charges = Stripe::Charge.list(limit: 5)
  successes << "#{charges.data.count} charge(s) récente(s)"
  puts "  ✅ #{charges.data.count} charge(s) récente(s)"
  
  charges.data.each_with_index do |charge, i|
    puts "     #{i+1}. #{charge.id}: #{charge.amount / 100.0}€ (#{charge.status})"
  end
rescue Stripe::StripeError => e
  errors << "Liste charges: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 5. Vérifier les transferts récents
puts "\n📋 5. TRANSFERTS RÉCENTS"
puts "-" * 50

begin
  transfers = Stripe::Transfer.list(limit: 5)
  successes << "#{transfers.data.count} transfert(s) récent(s)"
  puts "  ✅ #{transfers.data.count} transfert(s) récent(s)"
  
  transfers.data.each_with_index do |transfer, i|
    puts "     #{i+1}. #{transfer.id}: #{transfer.amount / 100.0}€ -> #{transfer.destination}"
  end
rescue Stripe::StripeError => e
  errors << "Liste transferts: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 6. Vérifier les remboursements récents
puts "\n📋 6. REMBOURSEMENTS RÉCENTS"
puts "-" * 50

begin
  refunds = Stripe::Refund.list(limit: 5)
  successes << "#{refunds.data.count} remboursement(s) récent(s)"
  puts "  ✅ #{refunds.data.count} remboursement(s) récent(s)"
  
  refunds.data.each_with_index do |refund, i|
    puts "     #{i+1}. #{refund.id}: #{refund.amount / 100.0}€ (#{refund.status})"
  end
rescue Stripe::StripeError => e
  errors << "Liste remboursements: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 7. Vérifier le solde du compte
puts "\n📋 7. SOLDE COMPTE PLATEFORME"
puts "-" * 50

begin
  balance = Stripe::Balance.retrieve
  successes << "Solde récupéré"
  puts "  ✅ Solde récupéré"
  
  balance.available.each do |b|
    puts "     Disponible: #{b.amount / 100.0} #{b.currency.upcase}"
  end
  balance.pending.each do |b|
    puts "     En attente: #{b.amount / 100.0} #{b.currency.upcase}"
  end
rescue Stripe::StripeError => e
  errors << "Solde: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# 8. Test création lien onboarding
puts "\n📋 8. CRÉATION LIEN ONBOARDING TEST"
puts "-" * 50

begin
  # Créer un compte Express de test
  account = Stripe::Account.create({
    type: 'express',
    country: 'FR',
    email: "test_#{Time.now.to_i}@fiatope-test.com",
    capabilities: {
      card_payments: { requested: true },
      transfers: { requested: true }
    },
    metadata: {
      test: 'true',
      platform: 'fiatope'
    }
  })
  
  successes << "Compte Express test créé: #{account.id}"
  puts "  ✅ Compte Express test créé: #{account.id}"
  
  # Créer le lien d'onboarding
  link = Stripe::AccountLink.create({
    account: account.id,
    refresh_url: 'https://fiatope.com/stripe/connect/refresh',
    return_url: 'https://fiatope.com/stripe/connect/return',
    type: 'account_onboarding'
  })
  
  successes << "Lien onboarding créé"
  puts "  ✅ Lien onboarding créé"
  puts "     URL: #{link.url[0..60]}..."
  
  # Supprimer le compte test
  deleted = Stripe::Account.delete(account.id)
  puts "  ✅ Compte test supprimé (nettoyage)"
  
rescue Stripe::StripeError => e
  errors << "Onboarding: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# RÉSUMÉ
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ TEST API STRIPE"
puts "=" * 70

puts "\n✅ SUCCÈS: #{successes.count}"
successes.each { |s| puts "   • #{s}" }

puts "\n❌ ERREURS: #{errors.count}"
errors.each { |e| puts "   • #{e}" }

score = (successes.count.to_f / (successes.count + errors.count) * 100).round(1) rescue 0
puts "\n📈 SCORE: #{score}%"

puts "\n" + "=" * 70
if errors.empty?
  puts "🎉 API STRIPE 100% FONCTIONNELLE!"
else
  puts "🚨 #{errors.count} erreur(s) API"
end
puts "=" * 70
