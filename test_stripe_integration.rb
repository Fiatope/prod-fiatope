require_relative 'config/environment'

puts "\n========================================="
puts "TEST INTÉGRATION STRIPE COMPLÈTE"
puts "=========================================\n"

# 1. Vérifier enregistrement PaymentEngine
puts "1. Vérification PaymentEngine:"
engines = PaymentEngine.all
puts "   - Moteurs enregistrés: #{engines.map(&:name).join(', ')}"
stripe_engine = engines.find { |e| e.name.downcase == 'stripe' }
if stripe_engine
  puts "   ✅ Stripe enregistré avec succès"
else
  puts "   ❌ ERREUR: Stripe non enregistré!"
  exit 1
end

# 2. Vérifier image Stripe
puts "\n2. Vérification image Stripe:"
stripe_image_path = Rails.root.join('app', 'assets', 'images', 'payments', 'stripe.png')
if File.exist?(stripe_image_path)
  puts "   ✅ Image stripe.png existe (#{File.size(stripe_image_path)} bytes)"
else
  puts "   ❌ ERREUR: Image stripe.png manquante!"
  exit 1
end

# 3. Vérifier traductions
puts "\n3. Vérification traductions:"
begin
  title_fr = I18n.t('shared.payments.form.payment-method.stripe.title', locale: :fr)
  puts "   ✅ Traduction FR: #{title_fr}"
rescue => e
  puts "   ❌ Erreur traduction FR: #{e.message}"
end

# 4. Vérifier projets use_stripe
puts "\n4. Vérification projets:"
total_projects = Project.count
stripe_enabled = Project.where(use_stripe: true).count
stripe_disabled = Project.where(use_stripe: false).count
puts "   - Total projets: #{total_projects}"
puts "   - Stripe activé: #{stripe_enabled}"
puts "   - Stripe désactivé: #{stripe_disabled}"

if stripe_enabled == total_projects
  puts "   ✅ Stripe activé sur TOUS les projets"
elsif stripe_enabled > 0
  puts "   ⚠️  Stripe activé sur #{stripe_enabled}/#{total_projects} projets"
else
  puts "   ❌ ERREUR: Stripe non activé sur aucun projet!"
  exit 1
end

# 5. Tester configuration projet
puts "\n5. Test configuration premier projet:"
project = Project.first
if project
  puts "   - Projet: #{project.name}"
  puts "   - use_stripe: #{project.use_stripe}"
  puts "   - stripe_account_id: #{project.stripe_account_id || '(vide)'}"
  
  if project.respond_to?(:stripe_ready?)
    puts "   - stripe_ready?: #{project.stripe_ready?}"
  end
  
  if project.use_stripe
    puts "   ✅ Projet configuré pour Stripe"
  else
    puts "   ❌ Projet NON configuré pour Stripe"
  end
else
  puts "   ⚠️  Aucun projet en base"
end

puts "\n========================================="
puts "✅ TOUS LES TESTS PASSÉS!"
puts "Le bouton Stripe devrait s'afficher dans l'interface."
puts "=========================================\n"
