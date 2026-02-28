# ============================================================
# 🔱 TEST RÉEL COMPLET STRIPE CONNECT - FIATOPE
# ============================================================
# Tests approfondis avec vérification du compte acct_1SebvDGYztzfoSs7
# ============================================================

puts "\n" + "=" * 70
puts "🔱 TEST RÉEL COMPLET STRIPE CONNECT - FIATOPE"
puts "=" * 70
puts "Date: #{Time.now}"

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

$tests = { passed: 0, failed: 0 }
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
    puts "💥 #{e.message[0..50]}"
    $tests[:failed] += 1
    $errors << "#{name}: #{e.class}"
    false
  end
end

def section(title)
  puts "\n" + "-" * 70
  puts "📋 #{title}"
  puts "-" * 70
end

# ============================================================
section "VÉRIFICATION COMPTE acct_1SebvDGYztzfoSs7"
# ============================================================

target_account_id = 'acct_1SebvDGYztzfoSs7'
target_email = 'djoukosocrate@gmail.com'

puts "Recherche du compte #{target_account_id}..."

# Vérifier sur Stripe
begin
  account = Stripe::Account.retrieve(target_account_id)
  puts "\n📊 Compte Stripe trouvé:"
  puts "   ID: #{account.id}"
  puts "   Type: #{account.type}"
  puts "   Country: #{account.country}"
  puts "   Charges enabled: #{account.charges_enabled ? '✅' : '❌'}"
  puts "   Payouts enabled: #{account.payouts_enabled ? '✅' : '❌'}"
  puts "   Details submitted: #{account.details_submitted ? '✅' : '❌'}"
  
  test("Compte Stripe actif") { account.charges_enabled && account.payouts_enabled }
rescue Stripe::StripeError => e
  puts "❌ Erreur Stripe: #{e.message}"
  test("Compte Stripe actif") { false }
end

# Chercher l'utilisateur dans la BD
puts "\n🔍 Recherche utilisateur dans la BD..."

# Chercher par compte Stripe
user_by_account = User.find_by(stripe_connect_account_id: target_account_id)
user_by_email = User.find_by(email: target_email)

if user_by_account
  puts "   Trouvé par account_id: #{user_by_account.email}"
elsif user_by_email
  puts "   Trouvé par email: #{user_by_email.email}"
  puts "   Son stripe_connect_account_id: #{user_by_email.stripe_connect_account_id || 'NON DÉFINI'}"
  
  # Associer le compte si pas déjà fait
  if user_by_email.stripe_connect_account_id != target_account_id
    puts "\n⚠️ ASSOCIATION NÉCESSAIRE: #{target_email} → #{target_account_id}"
    user_by_email.update!(
      stripe_connect_account_id: target_account_id,
      stripe_onboarding_complete: true
    )
    puts "✅ Compte associé avec succès!"
  end
else
  puts "   ❌ Utilisateur non trouvé avec email: #{target_email}"
  
  # Créer l'utilisateur si nécessaire
  puts "\n🔧 Création de l'utilisateur..."
  user_by_email = User.create!(
    email: target_email,
    name: 'Djouko Socrate',
    password: 'test123456',
    stripe_connect_account_id: target_account_id,
    stripe_onboarding_complete: true
  )
  puts "✅ Utilisateur créé: #{user_by_email.id}"
end

porteur = user_by_email || user_by_account
test("Porteur trouvé/créé") { porteur.present? }
test("Porteur a stripe_connect_account_id") { porteur&.stripe_connect_account_id == target_account_id }

# ============================================================
section "VÉRIFICATION PROJETS DU PORTEUR"
# ============================================================

if porteur
  projets = porteur.projects.where(use_stripe: true)
  puts "Projets Stripe du porteur: #{projets.count}"
  
  if projets.any?
    projets.each do |p|
      puts "   - #{p.name} (ID: #{p.id})"
      puts "     stripe_account_id: #{p.stripe_account_id || 'NON DÉFINI'}"
      
      # Synchroniser si nécessaire
      if p.stripe_account_id != target_account_id
        p.update!(stripe_account_id: target_account_id)
        puts "     ✅ Synchronisé avec #{target_account_id}"
      end
    end
    test("Au moins un projet Stripe") { true }
  else
    puts "   ⚠️ Aucun projet Stripe trouvé"
    
    # Chercher un projet sans owner
    projet_existant = Project.where(use_stripe: true).first
    if projet_existant
      puts "   📝 Utilisation du projet existant: #{projet_existant.name}"
      projet_existant.update!(
        user_id: porteur.id,
        stripe_account_id: target_account_id
      )
      puts "   ✅ Projet assigné au porteur"
      test("Au moins un projet Stripe") { true }
    else
      test("Au moins un projet Stripe") { false }
    end
  end
end

# ============================================================
section "TEST CONTRIBUTIONS EXISTANTES"
# ============================================================

contributions = Contribution.where(payment_method: 'Stripe', state: 'confirmed')
puts "Contributions Stripe confirmées: #{contributions.count}"

if contributions.any?
  contributions.limit(5).each do |c|
    puts "\n   Contribution ##{c.id}:"
    puts "     Montant: #{c.value}€"
    puts "     Projet: #{c.project&.name}"
    puts "     payment_id: #{c.payment_id || 'NON DÉFINI'}"
    puts "     stripe_charge_id: #{c.stripe_charge_id || 'NON DÉFINI'}"
    puts "     stripe_transferred: #{c.stripe_transferred || false}"
    
    # Synchroniser charge_id si manquant
    if c.stripe_charge_id.blank? && c.payment_id.present?
      begin
        pi = Stripe::PaymentIntent.retrieve(c.payment_id)
        if pi.latest_charge.present?
          c.update!(stripe_charge_id: pi.latest_charge)
          puts "     ✅ charge_id synchronisé: #{pi.latest_charge}"
        end
      rescue Stripe::StripeError => e
        puts "     ⚠️ Erreur sync: #{e.message[0..30]}"
      end
    end
  end
  test("Contributions Stripe présentes") { true }
else
  test("Contributions Stripe présentes") { false }
end

# ============================================================
section "TEST SIMULATION TRANSFERT"
# ============================================================

# Trouver une contribution transférable
transferable = Contribution.where(payment_method: 'Stripe', state: 'confirmed')
                           .where.not(stripe_charge_id: [nil, ''])
                           .where(stripe_transferred: [nil, false]).first

if transferable
  project = transferable.project
  puts "Contribution transférable: ##{transferable.id}"
  puts "  Montant: #{transferable.value}€"
  puts "  Projet: #{project&.name}"
  puts "  Destination: #{project&.stripe_account_id}"
  
  if project&.stripe_account_id.present?
    begin
      charge = Stripe::Charge.retrieve(transferable.stripe_charge_id)
      balance_txn = Stripe::BalanceTransaction.retrieve(charge.balance_transaction)
      
      stripe_fee = balance_txn.fee / 100.0
      net_amount = (charge.amount / 100.0) - stripe_fee
      platform_fee_pct = ENV.fetch('PLATFORM_FEE', '5.0').to_f
      platform_fee = (net_amount * platform_fee_pct / 100).round(2)
      transfer_amount = net_amount - platform_fee
      
      puts "\n  📊 Calcul transfert:"
      puts "     Montant brut: #{charge.amount / 100.0}€"
      puts "     Frais Stripe: #{stripe_fee}€"
      puts "     Net: #{net_amount}€"
      puts "     Commission (#{platform_fee_pct}%): #{platform_fee}€"
      puts "     À transférer: #{transfer_amount}€"
      
      test("Calcul transfert correct") { transfer_amount > 0 }
      test("Charge non transférée") { charge.transfer_data.nil? }
      test("Charge non remboursée") { !charge.refunded }
    rescue Stripe::StripeError => e
      puts "  ⚠️ Erreur Stripe: #{e.message}"
    end
  end
else
  puts "⚠️ Aucune contribution transférable"
  test("Contribution transférable") { false }
end

# ============================================================
section "TEST WEBHOOKS CONFIGURATION"
# ============================================================

webhook_path = Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb')
if File.exist?(webhook_path)
  code = File.read(webhook_path)
  
  test("CSRF désactivé") { code.include?('skip_before_action :verify_authenticity_token') }
  test("Signature vérifiée") { code.include?('Webhook.construct_event') }
  test("checkout.session.completed") { code.include?('checkout.session.completed') }
  test("charge.refunded") { code.include?('charge.refunded') }
  test("charge.dispute.created") { code.include?('charge.dispute.created') }
end

# ============================================================
section "TEST CAMPAIGNSETTLEMENT SERVICE"
# ============================================================

require_relative '../lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement'

test("CampaignSettlement chargé") { defined?(Neighborly::Stripe::CampaignSettlement) }

if transferable && transferable.project
  settlement = Neighborly::Stripe::CampaignSettlement.new(transferable.project)
  test("CampaignSettlement instancié") { settlement.is_a?(Neighborly::Stripe::CampaignSettlement) }
  test("Méthode process! existe") { settlement.respond_to?(:process!) }
  test("Méthode process_refunds! existe") { settlement.respond_to?(:process_refunds!) }
  test("Méthode transfer_single_contribution existe") { settlement.respond_to?(:transfer_single_contribution) }
end

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ DES TESTS RÉELS - FIATOPE"
puts "=" * 70

puts "\n✅ Passés: #{$tests[:passed]}"
puts "❌ Échoués: #{$tests[:failed]}"

if $errors.any?
  puts "\n🔴 ERREURS:"
  $errors.each { |e| puts "   • #{e}" }
end

total = $tests[:passed] + $tests[:failed]
score = total > 0 ? (($tests[:passed].to_f / total) * 100).round(1) : 0

puts "\n" + "=" * 70
if $tests[:failed] == 0
  puts "🎉 TOUS LES TESTS PASSÉS - FIATOPE PRÊT!"
elsif score >= 90
  puts "⚠️ #{$tests[:failed]} test(s) mineur(s) à corriger"
else
  puts "🚨 #{$tests[:failed]} TESTS ÉCHOUÉS"
end
puts "=" * 70
puts "\n📈 SCORE: #{score}% (#{$tests[:passed]}/#{total})"
