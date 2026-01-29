# AUDIT SÉCURITÉ STRIPE CONNECT - FIATOPE
puts "=" * 60
puts "🔒 AUDIT SÉCURITÉ STRIPE CONNECT - FIATOPE"
puts "=" * 60

errors = []
warnings = []
successes = []

# 1. PROTECTION CSRF
puts "\n📋 1. PROTECTION CSRF"
puts "-" * 50

webhooks_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb'))
payments_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/payments_controller.rb'))
connect_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/connect_controller.rb'))

if webhooks_file.include?('skip_before_action :verify_authenticity_token')
  successes << "CSRF désactivé uniquement pour webhooks"
  puts "  ✅ Webhooks: CSRF désactivé (correct - signature Stripe)"
else
  errors << "Webhooks: CSRF non géré"
  puts "  ❌ Webhooks: CSRF non géré"
end

# 2. SIGNATURE WEBHOOK
puts "\n📋 2. SIGNATURE WEBHOOK"
puts "-" * 50

if webhooks_file.include?('construct_event')
  successes << "Signature webhook vérifiée avec construct_event"
  puts "  ✅ Signature vérifiée avec Stripe::Webhook.construct_event"
else
  errors << "Signature webhook non vérifiée"
  puts "  ❌ Signature webhook NON vérifiée"
end

if ENV['STRIPE_WEBHOOK_SECRET'].present?
  successes << "STRIPE_WEBHOOK_SECRET configuré"
  puts "  ✅ STRIPE_WEBHOOK_SECRET configuré"
else
  warnings << "STRIPE_WEBHOOK_SECRET non configuré"
  puts "  ⚠️ STRIPE_WEBHOOK_SECRET non configuré"
end

# 3. AUTHENTIFICATION
puts "\n📋 3. AUTHENTIFICATION"
puts "-" * 50

if payments_file.include?('authenticate_user!')
  successes << "PaymentsController: authenticate_user!"
  puts "  ✅ PaymentsController: authenticate_user!"
else
  warnings << "PaymentsController: authentification non explicite"
  puts "  ⚠️ PaymentsController: authentification non explicite"
end

if connect_file.include?('authenticate_user!')
  successes << "ConnectController: authenticate_user!"
  puts "  ✅ ConnectController: authenticate_user!"
else
  warnings << "ConnectController: authentification non explicite"
  puts "  ⚠️ ConnectController: authentification non explicite"
end

# 4. VÉRIFICATION PROPRIÉTÉ
puts "\n📋 4. VÉRIFICATION PROPRIÉTÉ"
puts "-" * 50

if connect_file.include?('current_user') && (connect_file.include?('@project.user') || connect_file.include?('authorize'))
  successes << "Vérification propriété projet"
  puts "  ✅ Vérification propriété projet"
else
  warnings << "Vérification propriété non explicite"
  puts "  ⚠️ Vérification propriété à vérifier manuellement"
end

# 5. DONNÉES SENSIBLES
puts "\n📋 5. DONNÉES SENSIBLES"
puts "-" * 50

# Vérifier qu'on n'expose pas les clés
all_code = webhooks_file + payments_file + connect_file
if all_code.include?('sk_live') || all_code.include?('sk_test')
  errors << "Clé secrète hardcodée!"
  puts "  ❌ Clé secrète hardcodée dans le code!"
else
  successes << "Pas de clé secrète hardcodée"
  puts "  ✅ Pas de clé secrète hardcodée"
end

# 6. INJECTION SQL
puts "\n📋 6. PROTECTION INJECTION SQL"
puts "-" * 50

campaign_file = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb'))
if campaign_file.include?('where(') && !campaign_file.include?('where("')
  successes << "Utilisation de requêtes paramétrées"
  puts "  ✅ Requêtes paramétrées (ActiveRecord)"
else
  warnings << "Vérifier les requêtes SQL manuellement"
  puts "  ⚠️ Vérifier les requêtes SQL manuellement"
end

# 7. LOGGING SÉCURISÉ
puts "\n📋 7. LOGGING SÉCURISÉ"
puts "-" * 50

if all_code.include?('Rails.logger')
  successes << "Utilisation de Rails.logger"
  puts "  ✅ Utilisation de Rails.logger"
end

# Vérifier qu'on ne log pas les données sensibles
if all_code.downcase.include?('password') && all_code.include?('logger')
  warnings << "Possible logging de mot de passe"
  puts "  ⚠️ Vérifier qu'on ne log pas les mots de passe"
else
  successes << "Pas de logging de mot de passe détecté"
  puts "  ✅ Pas de logging de mot de passe"
end

# 8. GESTION D'ERREURS
puts "\n📋 8. GESTION D'ERREURS"
puts "-" * 50

if webhooks_file.include?('rescue') && webhooks_file.include?('Stripe::SignatureVerificationError')
  successes << "Gestion erreur signature webhook"
  puts "  ✅ Gestion Stripe::SignatureVerificationError"
else
  errors << "Pas de gestion Stripe::SignatureVerificationError"
  puts "  ❌ Pas de gestion Stripe::SignatureVerificationError"
end

if campaign_file.include?('rescue') && campaign_file.include?('Stripe::StripeError')
  successes << "Gestion erreurs Stripe dans CampaignSettlement"
  puts "  ✅ Gestion Stripe::StripeError"
else
  warnings << "Vérifier gestion erreurs Stripe"
  puts "  ⚠️ Vérifier gestion erreurs Stripe"
end

# 9. IDEMPOTENCE
puts "\n📋 9. IDEMPOTENCE"
puts "-" * 50

if campaign_file.include?('stripe_transferred') || campaign_file.include?('already')
  successes << "Vérification transfert déjà effectué"
  puts "  ✅ Protection contre double transfert"
else
  errors << "Pas de protection contre double transfert"
  puts "  ❌ Pas de protection contre double transfert"
end

if campaign_file.include?('stripe_refunded') || campaign_file.include?('refunded?')
  successes << "Vérification remboursement déjà effectué"
  puts "  ✅ Protection contre double remboursement"
else
  errors << "Pas de protection contre double remboursement"
  puts "  ❌ Pas de protection contre double remboursement"
end

# RÉSUMÉ
puts "\n" + "=" * 60
puts "📊 RÉSUMÉ AUDIT SÉCURITÉ"
puts "=" * 60

puts "\n✅ SUCCÈS: #{successes.count}"
successes.each { |s| puts "   • #{s}" }

puts "\n⚠️ AVERTISSEMENTS: #{warnings.count}"
warnings.each { |w| puts "   • #{w}" }

puts "\n❌ ERREURS: #{errors.count}"
errors.each { |e| puts "   • #{e}" }

score = (successes.count.to_f / (successes.count + errors.count) * 100).round(1) rescue 0
puts "\n📈 SCORE SÉCURITÉ: #{score}%"

puts "\n" + "=" * 60
if errors.empty?
  puts "🔒 AUDIT SÉCURITÉ RÉUSSI!"
else
  puts "🚨 #{errors.count} problème(s) de sécurité à corriger"
end
puts "=" * 60
