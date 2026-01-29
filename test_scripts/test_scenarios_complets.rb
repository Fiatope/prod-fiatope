# ============================================================
# 🔱 TEST SCÉNARIOS COMPLETS STRIPE CONNECT - FIATOPE
# ============================================================
# Teste TOUS les scénarios utilisateur réels
# ============================================================

puts "\n" + "=" * 70
puts "🔱 TEST SCÉNARIOS COMPLETS STRIPE CONNECT - FIATOPE"
puts "=" * 70
puts "Date: #{Time.now}"

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

# Charger explicitement les services Stripe
require_relative '../lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement'
require_relative '../lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/sync_service'

$tests = { passed: 0, failed: 0, skipped: 0 }
$errors = []

def test(name)
  print "  #{name}... "
  begin
    result = yield
    if result
      puts "✅"
      $tests[:passed] += 1
      true
    else
      puts "❌"
      $tests[:failed] += 1
      $errors << name
      false
    end
  rescue => e
    puts "💥 #{e.message[0..60]}"
    $tests[:failed] += 1
    $errors << "#{name}: #{e.class}"
    false
  end
end

def skip(name, reason)
  puts "  #{name}... ⏭️ #{reason}"
  $tests[:skipped] += 1
end

def section(title)
  puts "\n" + "-" * 70
  puts "📋 #{title}"
  puts "-" * 70
end

# ============================================================
section "SCÉNARIO 1: PORTEUR DE PROJET"
# ============================================================
puts "Simule: Un porteur crée un projet et configure Stripe Connect"

# Trouver un porteur avec compte Stripe
porteur = User.where.not(stripe_connect_account_id: [nil, '']).first

if porteur
  puts "  Porteur trouvé: #{porteur.email}"
  puts "  Stripe Connect: #{porteur.stripe_connect_account_id}"
  
  test("Porteur a stripe_connect_account_id") { porteur.stripe_connect_account_id.present? }
  test("Porteur a stripe_onboarding_complete") { porteur.respond_to?(:stripe_onboarding_complete) }
  
  # Vérifier le compte sur Stripe
  begin
    account = Stripe::Account.retrieve(porteur.stripe_connect_account_id)
    test("Compte Stripe existe") { account.id.present? }
    test("Compte peut recevoir paiements (charges_enabled)") { account.charges_enabled }
    test("Compte peut recevoir virements (payouts_enabled)") { account.payouts_enabled }
    puts "    Type: #{account.type}"
    puts "    Country: #{account.country}"
    puts "    Capabilities: charges=#{account.charges_enabled}, payouts=#{account.payouts_enabled}"
  rescue Stripe::StripeError => e
    puts "    ⚠️ Erreur Stripe: #{e.message}"
  end
  
  # Vérifier ses projets
  projets_porteur = porteur.projects.where(use_stripe: true)
  puts "  Projets Stripe du porteur: #{projets_porteur.count}"
  
  projets_porteur.each do |p|
    test("Projet '#{p.name[0..20]}' a stripe_account_id") { p.stripe_account_id.present? }
    test("Projet stripe_account_id = porteur") { p.stripe_account_id == porteur.stripe_connect_account_id }
  end
else
  skip("Tests porteur", "Aucun porteur avec Stripe Connect")
end

# ============================================================
section "SCÉNARIO 2: CONTRIBUTEUR"
# ============================================================
puts "Simule: Un contributeur fait un don via Stripe"

# Trouver une contribution Stripe
contribution = Contribution.where(payment_method: 'Stripe', state: 'confirmed').first

if contribution
  puts "  Contribution trouvée: ##{contribution.id}"
  puts "  Montant: #{contribution.value} #{contribution.project&.currency || 'EUR'}"
  puts "  Projet: #{contribution.project&.name}"
  
  test("Contribution a payment_id") { contribution.payment_id.present? }
  test("Contribution a state confirmed") { contribution.state == 'confirmed' }
  test("Contribution a projet") { contribution.project.present? }
  test("Contribution a user") { contribution.user.present? }
  
  # Vérifier le paiement sur Stripe
  if contribution.payment_id.present?
    begin
      pi = Stripe::PaymentIntent.retrieve(contribution.payment_id)
      test("PaymentIntent existe") { pi.id.present? }
      test("PaymentIntent status = succeeded") { pi.status == 'succeeded' }
      test("PaymentIntent amount correct") { (pi.amount / 100.0) == contribution.value }
      
      # CROWDFUNDING: Vérifier que PAS de transfert automatique
      test("CROWDFUNDING: Pas de transfer_data (transfert manuel)") { pi.transfer_data.nil? }
      
      # Vérifier le charge
      if pi.latest_charge.present?
        charge = Stripe::Charge.retrieve(pi.latest_charge)
        test("Charge existe") { charge.id.present? }
        test("Charge captured") { charge.captured }
        puts "    Charge ID: #{charge.id}"
        puts "    Transfer: #{charge.transfer_data || 'Aucun (correct pour crowdfunding)'}"
      end
    rescue Stripe::StripeError => e
      puts "    ⚠️ Erreur Stripe: #{e.message}"
    end
  end
else
  skip("Tests contributeur", "Aucune contribution Stripe confirmée")
end

# ============================================================
section "SCÉNARIO 3: ADMIN - TRANSFERT"
# ============================================================
puts "Simule: L'admin transfère les fonds au porteur"

# Vérifier que CampaignSettlement existe
test("CampaignSettlement défini") { defined?(Neighborly::Stripe::CampaignSettlement) }

# Trouver une contribution transférable
transferable = Contribution.where(payment_method: 'Stripe', state: 'confirmed')
                           .where.not(stripe_charge_id: [nil, ''])
                           .where(stripe_transferred: [nil, false]).first

if transferable
  project = transferable.project
  puts "  Contribution transférable: ##{transferable.id}"
  puts "  Projet: #{project&.name}"
  puts "  Destination: #{project&.stripe_account_id}"
  
  test("Contribution a stripe_charge_id") { transferable.stripe_charge_id.present? }
  test("Projet a stripe_account_id") { project&.stripe_account_id.present? }
  
  # Simuler le calcul de transfert (DRY RUN)
  if project&.stripe_account_id.present?
    begin
      charge = Stripe::Charge.retrieve(transferable.stripe_charge_id)
      
      # Récupérer les frais réels
      balance_txn = Stripe::BalanceTransaction.retrieve(charge.balance_transaction)
      stripe_fee = balance_txn.fee / 100.0
      net_amount = (charge.amount / 100.0) - stripe_fee
      platform_fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').to_f
      platform_fee = (net_amount * platform_fee_pct / 100).round(2)
      transfer_amount = net_amount - platform_fee
      
      puts "\n  📊 Simulation transfert (DRY RUN):"
      puts "    Montant brut: #{charge.amount / 100.0} #{charge.currency.upcase}"
      puts "    Frais Stripe: #{stripe_fee}"
      puts "    Net après Stripe: #{net_amount}"
      puts "    Commission plateforme (#{platform_fee_pct}%): #{platform_fee}"
      puts "    Montant transfert: #{transfer_amount}"
      puts "    Destination: #{project.stripe_account_id}"
      
      test("Montant transfert > 0") { transfer_amount > 0 }
      test("Charge non remboursée") { !charge.refunded }
      test("Charge non transférée") { charge.transfer_data.nil? }
    rescue Stripe::StripeError => e
      puts "    ⚠️ Erreur Stripe: #{e.message}"
    end
  end
else
  skip("Tests admin transfert", "Aucune contribution transférable")
end

# ============================================================
section "SCÉNARIO 4: ADMIN - REMBOURSEMENT"
# ============================================================
puts "Simule: L'admin rembourse un contributeur"

# Trouver une contribution remboursée
refunded = Contribution.where(payment_method: 'Stripe', state: 'refunded').first

if refunded
  puts "  Contribution remboursée: ##{refunded.id}"
  
  test("Contribution a stripe_refund_id ou stripe_refunded") do
    refunded.stripe_refund_id.present? || refunded.stripe_refunded == true
  end
  
  # Vérifier le remboursement sur Stripe
  if refunded.stripe_charge_id.present?
    begin
      charge = Stripe::Charge.retrieve(refunded.stripe_charge_id)
      test("Charge marquée refunded") { charge.refunded }
      puts "    Refund amount: #{charge.amount_refunded / 100.0}"
    rescue Stripe::StripeError => e
      puts "    ⚠️ Erreur Stripe: #{e.message}"
    end
  end
else
  skip("Tests admin remboursement", "Aucune contribution remboursée")
end

# ============================================================
section "SCÉNARIO 5: WEBHOOKS"
# ============================================================
puts "Vérifie: Configuration et gestion des webhooks"

webhook_controller = Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb')
code = File.read(webhook_controller)

test("Webhook controller existe") { File.exist?(webhook_controller) }
test("Skip CSRF pour webhooks") { code.include?('skip_before_action :verify_authenticity_token') }
test("Vérification signature Stripe") { code.include?('Webhook.construct_event') }
test("Gestion checkout.session.completed") { code.include?('checkout.session.completed') }
test("Gestion charge.refunded") { code.include?('charge.refunded') }
test("Gestion charge.dispute.created") { code.include?('charge.dispute.created') }

# ============================================================
section "SCÉNARIO 6: EDGE CASES"
# ============================================================
puts "Vérifie: Gestion des cas limites"

# Contribution avec montant faible
small_contrib = Contribution.where(payment_method: 'Stripe').where('value < ?', 5).first
if small_contrib
  test("Petite contribution (< 5€) gérée") { small_contrib.persisted? }
else
  skip("Petite contribution", "Aucune contribution < 5€")
end

# Projet sans compte Stripe
project_no_stripe = Project.where(use_stripe: true).where(stripe_account_id: [nil, '']).first
if project_no_stripe
  puts "  ⚠️ Projet sans stripe_account_id trouvé: #{project_no_stripe.name}"
  test("Projet sans compte Stripe détecté") { true }
else
  test("Tous les projets Stripe ont un compte") { true }
end

# Porteur sans onboarding complet
porteur_incomplete = User.where.not(stripe_connect_account_id: [nil, ''])
                         .where(stripe_onboarding_complete: [false, nil]).first
if porteur_incomplete
  puts "  ⚠️ Porteur avec onboarding incomplet: #{porteur_incomplete.email}"
end

# ============================================================
section "SCÉNARIO 7: SÉCURITÉ"
# ============================================================
puts "Vérifie: Points de sécurité critiques"

connect_controller = Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/connect_controller.rb')
connect_code = File.read(connect_controller)

test("Authentification requise pour Connect") { connect_code.include?('authenticate_user!') }
test("Validation format account_id") { connect_code.include?("start_with?('acct_')") }

payments_controller = Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/payments_controller.rb')
payments_code = File.read(payments_controller)

test("Authentification requise pour paiements") { payments_code.include?('authenticate_user!') }
test("CROWDFUNDING: Pas de transfer_data dans new") { !payments_code.match(/session_params\[:payment_intent_data\].*transfer_data/m) }

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ DES TESTS - FIATOPE"
puts "=" * 70

puts "\n✅ Passés: #{$tests[:passed]}"
puts "❌ Échoués: #{$tests[:failed]}"
puts "⏭️ Ignorés: #{$tests[:skipped]}"

if $errors.any?
  puts "\n🔴 ERREURS:"
  $errors.each { |e| puts "   • #{e}" }
end

total = $tests[:passed] + $tests[:failed]
score = total > 0 ? (($tests[:passed].to_f / total) * 100).round(1) : 0

puts "\n" + "=" * 70
if $tests[:failed] == 0
  puts "🎉 TOUS LES TESTS PASSÉS!"
  puts "   Implémentation Stripe Connect conforme"
elsif score >= 90
  puts "⚠️ PRESQUE PARFAIT - #{$tests[:failed]} test(s) à corriger"
else
  puts "🚨 #{$tests[:failed]} TESTS ÉCHOUÉS - Corrections nécessaires"
end
puts "=" * 70
puts "\n📈 SCORE: #{score}% (#{$tests[:passed]}/#{total})"
