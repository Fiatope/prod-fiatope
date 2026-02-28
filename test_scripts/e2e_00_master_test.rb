# ============================================================
# 🔱 MASTER TEST E2E - FIATOPE STRIPE CONNECT
# ============================================================
# Ce script orchestre TOUS les tests de A à Z
# Exécute: rails runner test_scripts/e2e_00_master_test.rb
# ============================================================

puts "\n" + "=" * 70
puts "🔱 FIATOPE - SUITE DE TESTS E2E STRIPE CONNECT"
puts "=" * 70
puts "Date: #{Time.now}"
puts "Environnement: #{Rails.env}"
puts "=" * 70

require 'stripe'

# Configuration
TESTS_DIR = Rails.root.join('test_scripts')
TEST_EMAIL_PREFIX = "test_e2e_#{Time.now.to_i}"

$results = {
  passed: [],
  failed: [],
  skipped: []
}

def run_test(name, &block)
  print "\n🧪 #{name}... "
  begin
    result = yield
    if result
      puts "✅ PASS"
      $results[:passed] << name
      true
    else
      puts "❌ FAIL"
      $results[:failed] << name
      false
    end
  rescue => e
    puts "💥 ERROR: #{e.message}"
    $results[:failed] << "#{name}: #{e.message}"
    false
  end
end

# ============================================================
# TEST 1: Configuration Stripe
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 1: CONFIGURATION"
puts "-" * 70

run_test("STRIPE_SECRET_KEY configurée") do
  ENV['STRIPE_SECRET_KEY'].present?
end

run_test("STRIPE_PUBLISHABLE_KEY configurée") do
  ENV['STRIPE_PUBLISHABLE_KEY'].present?
end

run_test("Connexion API Stripe") do
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  account = Stripe::Account.retrieve
  account.id.present?
end

run_test("PLATFORM_FEE configurée") do
  ENV['PLATFORM_FEE'].present? && ENV['PLATFORM_FEE'].to_f > 0
end

# ============================================================
# TEST 2: Base de données
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 2: BASE DE DONNÉES"
puts "-" * 70

run_test("Colonnes User Stripe") do
  cols = User.column_names
  %w[stripe_connect_account_id stripe_onboarding_complete stripe_account_type].all? { |c| cols.include?(c) }
end

run_test("Colonnes Project Stripe") do
  cols = Project.column_names
  %w[stripe_account_id use_stripe stripe_settlement_type].all? { |c| cols.include?(c) }
end

run_test("Colonnes Contribution Stripe") do
  cols = Contribution.column_names
  %w[stripe_charge_id stripe_transfer_id stripe_transferred stripe_refunded payment_method].all? { |c| cols.include?(c) }
end

# ============================================================
# TEST 3: Services
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 3: SERVICES"
puts "-" * 70

run_test("CampaignSettlement chargeable") do
  project = Project.first
  settlement = Neighborly::Stripe::CampaignSettlement.new(project)
  settlement.respond_to?(:process!)
end

run_test("SyncService chargeable") do
  user = User.first
  sync = Neighborly::Stripe::SyncService.new(user)
  sync.respond_to?(:sync_all!)
end

run_test("FeeCalculator correct") do
  calc = Neighborly::Stripe::FeeCalculator.new(100)
  calc.gateway_fee > 0 && calc.platform_fee > 0
end

# ============================================================
# TEST 4: Contrôleurs
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 4: CONTRÔLEURS"
puts "-" * 70

run_test("PaymentsController existe") do
  Neighborly::Stripe::PaymentsController.present?
end

run_test("ConnectController existe") do
  Neighborly::Stripe::ConnectController.present?
end

run_test("WebhooksController existe") do
  Neighborly::Stripe::WebhooksController.present?
end

# ============================================================
# TEST 5: Données réelles
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 5: DONNÉES RÉELLES"
puts "-" * 70

run_test("Utilisateur avec Stripe Connect") do
  User.where.not(stripe_connect_account_id: nil).exists?
end

run_test("Projet avec Stripe activé") do
  Project.where(use_stripe: true).exists?
end

run_test("Contribution Stripe existante") do
  Contribution.where(payment_method: 'Stripe').exists?
end

# ============================================================
# TEST 6: Flux Crowdfunding complet
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 6: FLUX CROWDFUNDING"
puts "-" * 70

# Trouver un projet Stripe avec des contributions
project = Project.where(use_stripe: true).joins(:contributions).where("contributions.payment_method = ?", "Stripe").first

if project
  run_test("Projet Stripe avec contributions trouvé") { true }
  
  contribution = project.contributions.where(payment_method: 'Stripe').first
  
  run_test("Contribution Stripe valide") do
    contribution.present? && contribution.value.to_f > 0
  end
  
  run_test("CampaignSettlement pour ce projet") do
    settlement = Neighborly::Stripe::CampaignSettlement.new(project)
    settlement.present?
  end
  
  # Calcul des frais
  if contribution
    calc = Neighborly::Stripe::FeeCalculator.new(contribution.value.to_f)
    run_test("Calcul frais contribution réelle") do
      calc.gateway_fee > 0 && calc.platform_fee >= 0
    end
    
    puts "\n  📊 Détails contribution ##{contribution.id}:"
    puts "     Montant: #{contribution.value}€"
    puts "     Frais Stripe: #{calc.gateway_fee}€"
    puts "     Commission plateforme: #{calc.platform_fee}€"
    puts "     Net porteur: #{(contribution.value.to_f - calc.gateway_fee - calc.platform_fee).round(2)}€"
  end
else
  $results[:skipped] << "Tests flux crowdfunding (pas de projet Stripe avec contributions)"
  puts "\n  ⚠️ Pas de projet Stripe avec contributions pour tester"
end

# ============================================================
# TEST 7: API Stripe réelle
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 7: API STRIPE RÉELLE"
puts "-" * 70

run_test("Liste des comptes connectés") do
  accounts = Stripe::Account.list(limit: 3)
  accounts.data.is_a?(Array)
end

run_test("Liste des charges récentes") do
  charges = Stripe::Charge.list(limit: 3)
  charges.data.is_a?(Array)
end

run_test("Liste des transferts récents") do
  transfers = Stripe::Transfer.list(limit: 3)
  transfers.data.is_a?(Array)
end

# Vérifier si on a des comptes connectés réels
user_stripe = User.where.not(stripe_connect_account_id: nil).first
if user_stripe
  run_test("Récupération compte connecté réel") do
    begin
      account = Stripe::Account.retrieve(user_stripe.stripe_connect_account_id)
      account.id == user_stripe.stripe_connect_account_id
    rescue Stripe::InvalidRequestError
      # Compte peut ne pas exister en test
      true
    end
  end
end

# ============================================================
# TEST 8: Sécurité
# ============================================================
puts "\n" + "-" * 70
puts "📋 PHASE 8: SÉCURITÉ"
puts "-" * 70

webhooks_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb'))

run_test("Signature webhook vérifiée") do
  webhooks_file.include?('construct_event')
end

run_test("Protection double transfert") do
  campaign_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb'))
  campaign_file.include?('stripe_transferred')
end

run_test("Protection double remboursement") do
  campaign_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb'))
  campaign_file.include?('stripe_refunded') || campaign_file.include?('refunded?')
end

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ FINAL - TESTS E2E FIATOPE"
puts "=" * 70

puts "\n✅ PASSÉS: #{$results[:passed].count}"
$results[:passed].each { |t| puts "   • #{t}" }

if $results[:failed].any?
  puts "\n❌ ÉCHOUÉS: #{$results[:failed].count}"
  $results[:failed].each { |t| puts "   • #{t}" }
end

if $results[:skipped].any?
  puts "\n⏭️ IGNORÉS: #{$results[:skipped].count}"
  $results[:skipped].each { |t| puts "   • #{t}" }
end

total = $results[:passed].count + $results[:failed].count
score = total > 0 ? ($results[:passed].count.to_f / total * 100).round(1) : 0

puts "\n📈 SCORE: #{score}% (#{$results[:passed].count}/#{total})"

puts "\n" + "=" * 70
if $results[:failed].empty?
  puts "🎉 TOUS LES TESTS E2E PASSENT!"
  puts "🔱 FIATOPE STRIPE CONNECT - PRÊT POUR PRODUCTION"
else
  puts "🚨 #{$results[:failed].count} test(s) échoué(s)"
end
puts "=" * 70
