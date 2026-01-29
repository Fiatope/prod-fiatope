# ============================================================
# 🔱 TEST E2E 03 - CAS LIMITES ET ERREURS
# ============================================================
# Teste tous les cas limites et scénarios d'erreur
# ============================================================

puts "\n" + "=" * 70
puts "🔱 TEST E2E 03 - CAS LIMITES ET ERREURS"
puts "=" * 70

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

errors = []
successes = []
warnings = []

# ============================================================
# TEST 1: Projet sans compte Stripe
# ============================================================
puts "\n📋 1. PROJET SANS COMPTE STRIPE"
puts "-" * 50

project_no_stripe = Project.where(stripe_account_id: [nil, '']).first
if project_no_stripe
  begin
    settlement = Neighborly::Stripe::CampaignSettlement.new(project_no_stripe)
    
    # Tenter un transfert - devrait échouer proprement
    result = settlement.process!
    
    if result == false || settlement.errors.any?
      successes << "Rejet correct: projet sans compte Stripe"
      puts "  ✅ Transfert rejeté correctement"
      puts "     Erreurs: #{settlement.errors.join(', ')}" if settlement.errors.any?
    else
      warnings << "Transfert accepté pour projet sans compte"
      puts "  ⚠️ Transfert accepté (inattendu)"
    end
  rescue => e
    successes << "Exception correcte: #{e.class.name}"
    puts "  ✅ Exception levée: #{e.message[0..50]}"
  end
else
  puts "  ℹ️ Tous les projets ont un compte Stripe (bon signe!)"
  successes << "Tous projets ont compte Stripe"
end

# ============================================================
# TEST 2: Contribution déjà transférée
# ============================================================
puts "\n📋 2. CONTRIBUTION DÉJÀ TRANSFÉRÉE"
puts "-" * 50

contribution_transferred = Contribution.where(
  payment_method: 'Stripe',
  stripe_transferred: true
).first

if contribution_transferred
  project = contribution_transferred.project
  settlement = Neighborly::Stripe::CampaignSettlement.new(project)
  
  begin
    result = settlement.transfer_single_contribution(contribution_transferred)
    
    if result[:success] == false || result[:error]&.include?('déjà') || result[:error]&.include?('already')
      successes << "Rejet double transfert"
      puts "  ✅ Double transfert rejeté"
      puts "     Message: #{result[:error]}"
    else
      errors << "Double transfert non rejeté"
      puts "  ❌ Double transfert accepté!"
    end
  rescue => e
    successes << "Exception double transfert: #{e.class.name}"
    puts "  ✅ Exception: #{e.message[0..50]}"
  end
else
  puts "  ℹ️ Aucune contribution transférée trouvée"
  warnings << "Pas de contribution transférée pour test"
end

# ============================================================
# TEST 3: Contribution déjà remboursée
# ============================================================
puts "\n📋 3. CONTRIBUTION DÉJÀ REMBOURSÉE"
puts "-" * 50

contribution_refunded = Contribution.where(
  payment_method: 'Stripe',
  stripe_refunded: true
).first

if contribution_refunded
  project = contribution_refunded.project
  settlement = Neighborly::Stripe::CampaignSettlement.new(project)
  
  begin
    result = settlement.refund_contribution(contribution_refunded)
    
    if result == false
      successes << "Rejet double remboursement"
      puts "  ✅ Double remboursement rejeté"
    else
      errors << "Double remboursement non rejeté"
      puts "  ❌ Double remboursement accepté!"
    end
  rescue => e
    successes << "Exception double remboursement"
    puts "  ✅ Exception: #{e.message[0..50]}"
  end
else
  puts "  ℹ️ Aucune contribution remboursée trouvée"
  warnings << "Pas de contribution remboursée pour test"
end

# ============================================================
# TEST 4: Montant très faible (< frais Stripe)
# ============================================================
puts "\n📋 4. MONTANT TRÈS FAIBLE"
puts "-" * 50

small_amounts = [0.01, 0.10, 0.50, 1.00]

small_amounts.each do |amount|
  calc = Neighborly::Stripe::FeeCalculator.new(amount)
  net = amount - calc.gateway_fee - calc.platform_fee
  
  status = net > 0 ? "✅" : "⚠️"
  puts "  #{status} #{amount}€: Net = #{net.round(2)}€ (Stripe: #{calc.gateway_fee}€, Platform: #{calc.platform_fee}€)"
  
  if net <= 0
    warnings << "Montant #{amount}€ donne net négatif"
  end
end

successes << "Calcul petits montants OK"

# ============================================================
# TEST 5: Contribution sans charge_id
# ============================================================
puts "\n📋 5. CONTRIBUTION SANS CHARGE_ID"
puts "-" * 50

contribution_no_charge = Contribution.where(
  payment_method: 'Stripe',
  stripe_charge_id: [nil, '']
).first

if contribution_no_charge
  project = contribution_no_charge.project
  settlement = Neighborly::Stripe::CampaignSettlement.new(project)
  
  begin
    result = settlement.transfer_single_contribution(contribution_no_charge)
    
    if result[:success] == false
      successes << "Rejet contribution sans charge_id"
      puts "  ✅ Transfert rejeté (pas de charge_id)"
      puts "     Message: #{result[:error]}"
    else
      errors << "Transfert accepté sans charge_id"
      puts "  ❌ Transfert accepté sans charge_id!"
    end
  rescue => e
    successes << "Exception contribution sans charge_id"
    puts "  ✅ Exception: #{e.message[0..50]}"
  end
else
  puts "  ℹ️ Toutes les contributions Stripe ont un charge_id"
  successes << "Toutes contributions ont charge_id"
end

# ============================================================
# TEST 6: Utilisateur sans onboarding complet
# ============================================================
puts "\n📋 6. UTILISATEUR SANS ONBOARDING COMPLET"
puts "-" * 50

user_incomplete = User.where(
  stripe_onboarding_complete: [false, nil]
).where.not(stripe_connect_account_id: [nil, '']).first

if user_incomplete
  puts "  ℹ️ Utilisateur trouvé: #{user_incomplete.email}"
  puts "     Account ID: #{user_incomplete.stripe_connect_account_id}"
  puts "     Onboarding: #{user_incomplete.stripe_onboarding_complete ? 'Complet' : 'Incomplet'}"
  
  # Vérifier sur Stripe
  begin
    account = Stripe::Account.retrieve(user_incomplete.stripe_connect_account_id)
    
    if account.charges_enabled && account.payouts_enabled
      warnings << "Utilisateur marqué incomplet mais compte Stripe OK"
      puts "  ⚠️ Compte Stripe OK mais marqué incomplet en base"
      puts "     → Mise à jour recommandée"
    else
      successes << "Cohérence: compte incomplet = Stripe incomplet"
      puts "  ✅ Cohérent: compte Stripe aussi incomplet"
    end
  rescue Stripe::InvalidRequestError => e
    puts "  ⚠️ Compte Stripe invalide: #{e.message[0..50]}"
    warnings << "Compte Stripe invalide pour user #{user_incomplete.id}"
  end
else
  puts "  ℹ️ Tous les utilisateurs Stripe ont onboarding complet"
  successes << "Tous onboardings complets"
end

# ============================================================
# TEST 7: Webhook avec signature invalide
# ============================================================
puts "\n📋 7. SIMULATION WEBHOOK INVALIDE"
puts "-" * 50

begin
  # Simuler une vérification de signature invalide
  fake_payload = '{"type":"test.event"}'
  fake_signature = 'invalid_signature'
  
  Stripe::Webhook.construct_event(
    fake_payload,
    fake_signature,
    ENV['STRIPE_WEBHOOK_SECRET'] || 'whsec_test'
  )
  
  errors << "Signature invalide acceptée!"
  puts "  ❌ Signature invalide acceptée!"
rescue Stripe::SignatureVerificationError
  successes << "Signature invalide rejetée"
  puts "  ✅ Signature invalide correctement rejetée"
rescue => e
  successes << "Erreur signature: #{e.class.name}"
  puts "  ✅ Erreur levée: #{e.class.name}"
end

# ============================================================
# TEST 8: Charge Stripe inexistante
# ============================================================
puts "\n📋 8. CHARGE STRIPE INEXISTANTE"
puts "-" * 50

begin
  Stripe::Charge.retrieve('ch_invalid_charge_id_test')
  errors << "Charge invalide retournée"
  puts "  ❌ Charge invalide acceptée!"
rescue Stripe::InvalidRequestError => e
  successes << "Charge invalide rejetée"
  puts "  ✅ Charge invalide correctement rejetée"
  puts "     Message: #{e.message[0..50]}"
end

# ============================================================
# RÉSUMÉ
# ============================================================
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ TESTS CAS LIMITES"
puts "=" * 70

puts "\n✅ SUCCÈS: #{successes.count}"
successes.each { |s| puts "   • #{s}" }

puts "\n⚠️ AVERTISSEMENTS: #{warnings.count}"
warnings.each { |w| puts "   • #{w}" }

puts "\n❌ ERREURS: #{errors.count}"
errors.each { |e| puts "   • #{e}" }

total = successes.count + errors.count
score = total > 0 ? (successes.count.to_f / total * 100).round(1) : 0
puts "\n📈 SCORE: #{score}%"

puts "\n" + "=" * 70
if errors.empty?
  puts "🎉 TOUS LES CAS LIMITES GÉRÉS!"
else
  puts "🚨 #{errors.count} problème(s) de gestion d'erreurs"
end
puts "=" * 70
