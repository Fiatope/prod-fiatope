# AUDIT COMPLET STRIPE CONNECT - FIATOPE
puts "=" * 70
puts "🔍 AUDIT COMPLET STRIPE CONNECT - FIATOPE"
puts "=" * 70
puts "Date: #{Time.now}"

require 'stripe'

errors = []
warnings = []
successes = []

# === 1. CONFIGURATION ===
puts "\n📋 1. CONFIGURATION"
puts "-" * 50

begin
  if ENV['STRIPE_SECRET_KEY'].present?
    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    successes << "STRIPE_SECRET_KEY configurée"
    puts "  ✅ STRIPE_SECRET_KEY"
  else
    errors << "STRIPE_SECRET_KEY non configurée"
    puts "  ❌ STRIPE_SECRET_KEY"
  end
rescue => e
  errors << "Erreur config: #{e.message}"
end

%w[STRIPE_PUBLISHABLE_KEY PLATFORM_FEE].each do |var|
  if ENV[var].present?
    successes << "#{var} configurée"
    puts "  ✅ #{var}: #{ENV[var]}"
  else
    warnings << "#{var} non configurée"
    puts "  ⚠️ #{var}"
  end
end

if ENV['STRIPE_WEBHOOK_SECRET'].present?
  successes << "STRIPE_WEBHOOK_SECRET configurée"
  puts "  ✅ STRIPE_WEBHOOK_SECRET"
else
  warnings << "STRIPE_WEBHOOK_SECRET non configurée (production!)"
  puts "  ⚠️ STRIPE_WEBHOOK_SECRET - configurer en production!"
end

# === 2. CONNEXION API STRIPE ===
puts "\n📋 2. CONNEXION API STRIPE"
puts "-" * 50

begin
  if ENV['STRIPE_SECRET_KEY'].present?
    account = Stripe::Account.retrieve
    successes << "Connexion API Stripe OK (#{account.id})"
    puts "  ✅ Connexion API: #{account.id}"
  else
    warnings << "Impossible de tester connexion API sans clé"
    puts "  ⚠️ Impossible de tester sans clé"
  end
rescue Stripe::StripeError => e
  errors << "Erreur connexion Stripe: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# === 3. MODÈLES - COLONNES ===
puts "\n📋 3. MODÈLES - COLONNES STRIPE"
puts "-" * 50

user_cols = User.column_names
required_user_cols = %w[stripe_connect_account_id stripe_onboarding_complete stripe_account_type stripe_charges_enabled stripe_payouts_enabled]
required_user_cols.each do |col|
  if user_cols.include?(col)
    successes << "User.#{col}"
    puts "  ✅ User.#{col}"
  else
    errors << "User.#{col} MANQUANT"
    puts "  ❌ User.#{col} MANQUANT"
  end
end

project_cols = Project.column_names
required_project_cols = %w[stripe_account_id use_stripe stripe_settlement_type]
required_project_cols.each do |col|
  if project_cols.include?(col)
    successes << "Project.#{col}"
    puts "  ✅ Project.#{col}"
  else
    errors << "Project.#{col} MANQUANT"
    puts "  ❌ Project.#{col} MANQUANT"
  end
end

contribution_cols = Contribution.column_names
required_contribution_cols = %w[stripe_charge_id stripe_transfer_id stripe_transferred stripe_refunded payment_method]
required_contribution_cols.each do |col|
  if contribution_cols.include?(col)
    successes << "Contribution.#{col}"
    puts "  ✅ Contribution.#{col}"
  else
    errors << "Contribution.#{col} MANQUANT"
    puts "  ❌ Contribution.#{col} MANQUANT"
  end
end

# === 4. SERVICES ===
puts "\n📋 4. SERVICES STRIPE"
puts "-" * 50

begin
  settlement = Neighborly::Stripe::CampaignSettlement.new(Project.first)
  successes << "CampaignSettlement chargé"
  puts "  ✅ CampaignSettlement"
  
  methods = settlement.class.instance_methods(false)
  %i[process! process_refunds! transfer_single_contribution refund_contribution].each do |m|
    if methods.include?(m)
      successes << "CampaignSettlement##{m}"
      puts "    ✅ #{m}"
    else
      errors << "CampaignSettlement##{m} MANQUANT"
      puts "    ❌ #{m} MANQUANT"
    end
  end
rescue => e
  errors << "CampaignSettlement erreur: #{e.message}"
  puts "  ❌ CampaignSettlement: #{e.message}"
end

begin
  sync = Neighborly::Stripe::SyncService.new(User.first)
  successes << "SyncService chargé"
  puts "  ✅ SyncService"
rescue => e
  errors << "SyncService erreur: #{e.message}"
  puts "  ❌ SyncService: #{e.message}"
end

begin
  calc = Neighborly::Stripe::FeeCalculator.new(100)
  if calc.gateway_fee > 0 && calc.platform_fee >= 0
    successes << "FeeCalculator OK"
    puts "  ✅ FeeCalculator (fee: #{calc.gateway_fee}, platform: #{calc.platform_fee})"
  end
rescue => e
  errors << "FeeCalculator erreur: #{e.message}"
  puts "  ❌ FeeCalculator: #{e.message}"
end

# === 5. CONTRÔLEURS ===
puts "\n📋 5. CONTRÔLEURS STRIPE"
puts "-" * 50

controllers = [
  'Neighborly::Stripe::PaymentsController',
  'Neighborly::Stripe::ConnectController',
  'Neighborly::Stripe::WebhooksController'
]

controllers.each do |ctrl|
  begin
    ctrl.constantize
    successes << "#{ctrl}"
    puts "  ✅ #{ctrl}"
  rescue => e
    errors << "#{ctrl} MANQUANT"
    puts "  ❌ #{ctrl}"
  end
end

# === 6. ROUTES ===
puts "\n📋 6. ROUTES STRIPE"
puts "-" * 50

routes_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/config/routes.rb'))
required_routes = ['webhooks', 'connect', 'payments', 'success', 'cancel']
required_routes.each do |route|
  if routes_file.include?(route)
    successes << "Route #{route}"
    puts "  ✅ Route: #{route}"
  else
    warnings << "Route #{route} non trouvée"
    puts "  ⚠️ Route: #{route}"
  end
end

# === 7. WEBHOOKS ===
puts "\n📋 7. WEBHOOKS"
puts "-" * 50

webhooks_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb'))
webhook_events = [
  'checkout.session.completed',
  'payment_intent.succeeded',
  'charge.refunded',
  'account.updated'
]

webhook_events.each do |event|
  if webhooks_file.include?(event)
    successes << "Webhook: #{event}"
    puts "  ✅ #{event}"
  else
    warnings << "Webhook: #{event} non géré"
    puts "  ⚠️ #{event}"
  end
end

# Vérifier signature webhook
if webhooks_file.include?('construct_event') || webhooks_file.include?('verify_stripe_signature')
  successes << "Signature webhook vérifiée"
  puts "  ✅ Vérification signature"
else
  errors << "Signature webhook NON vérifiée"
  puts "  ❌ Vérification signature MANQUANTE"
end

# === 8. SÉCURITÉ ===
puts "\n📋 8. SÉCURITÉ"
puts "-" * 50

# CSRF désactivé uniquement pour webhooks
if webhooks_file.include?('skip_before_action :verify_authenticity_token')
  successes << "CSRF désactivé pour webhooks (correct)"
  puts "  ✅ CSRF webhooks"
end

payments_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/payments_controller.rb'))
if payments_file.include?('authenticate_user!')
  successes << "Authentification PaymentsController"
  puts "  ✅ Authentification payments"
else
  warnings << "Authentification PaymentsController non explicite"
  puts "  ⚠️ Authentification payments"
end

# === 9. DONNÉES RÉELLES ===
puts "\n📋 9. DONNÉES RÉELLES"
puts "-" * 50

user_stripe = User.where.not(stripe_connect_account_id: nil).first
if user_stripe
  successes << "Utilisateur Stripe: #{user_stripe.email}"
  puts "  ✅ Utilisateur Stripe: #{user_stripe.email}"
else
  warnings << "Aucun utilisateur Stripe Connect"
  puts "  ⚠️ Aucun utilisateur Stripe Connect"
end

project_stripe = Project.where(use_stripe: true).first
if project_stripe
  successes << "Projet Stripe: #{project_stripe.name}"
  puts "  ✅ Projet Stripe: #{project_stripe.name}"
else
  warnings << "Aucun projet Stripe"
  puts "  ⚠️ Aucun projet Stripe"
end

contribution_stripe = Contribution.where(payment_method: 'Stripe').first
if contribution_stripe
  successes << "Contribution Stripe: ##{contribution_stripe.id}"
  puts "  ✅ Contribution Stripe: ##{contribution_stripe.id}"
else
  warnings << "Aucune contribution Stripe"
  puts "  ⚠️ Aucune contribution Stripe"
end

# === 10. COMPARAISON AVEC KWENDOO ===
puts "\n📋 10. COMPARAISON AVEC KWENDOO"
puts "-" * 50

kwendoo_path = Rails.root.join('..', 'prod-kwendoo', 'lib', 'neighborly-stripe-0.1.0')
if File.exist?(kwendoo_path)
  fiatope_files = Dir.glob("#{Rails.root.join('lib/neighborly-stripe-0.1.0')}/**/*.rb").map { |f| File.basename(f) }
  kwendoo_files = Dir.glob("#{kwendoo_path}/**/*.rb").map { |f| File.basename(f) }
  
  missing = kwendoo_files - fiatope_files
  if missing.empty?
    successes << "Tous les fichiers Kwendoo présents"
    puts "  ✅ Parité avec Kwendoo"
  else
    warnings << "Fichiers manquants vs Kwendoo: #{missing.join(', ')}"
    puts "  ⚠️ Fichiers différents: #{missing.join(', ')}"
  end
else
  puts "  ⚠️ Kwendoo non accessible pour comparaison"
end

# === RÉSUMÉ ===
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ AUDIT STRIPE FIATOPE"
puts "=" * 70

puts "\n✅ SUCCÈS: #{successes.count}"
successes.each { |s| puts "   • #{s}" }

puts "\n⚠️ AVERTISSEMENTS: #{warnings.count}"
warnings.each { |w| puts "   • #{w}" }

puts "\n❌ ERREURS: #{errors.count}"
errors.each { |e| puts "   • #{e}" }

score = (successes.count.to_f / (successes.count + errors.count) * 100).round(1) rescue 0
puts "\n📈 SCORE: #{score}%"

puts "\n" + "=" * 70
if errors.empty?
  puts "🎉 AUDIT FIATOPE RÉUSSI!"
else
  puts "🚨 #{errors.count} erreur(s) à corriger"
end
puts "=" * 70
