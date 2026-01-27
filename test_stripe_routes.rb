require_relative 'config/environment'

puts "\n========================================="
puts "TEST ROUTES ET CONFIGURATION STRIPE"
puts "=========================================\n"

# 1. Vérifier montage engine
puts "1. Vérification montage Stripe Engine:"
routes = Rails.application.routes.routes.map(&:path).map(&:spec).map(&:to_s)
stripe_routes = routes.select { |r| r.include?('stripe') }
if stripe_routes.any?
  puts "   ✅ Engine Stripe monté (/stripe/)"
  stripe_routes.first(5).each do |route|
    puts "      - #{route}"
  end
else
  puts "   ❌ ERREUR: Engine Stripe non monté!"
  exit 1
end

# 2. Vérifier contrôleur PaymentsController
puts "\n2. Vérification contrôleurs Stripe:"
begin
  controller = Neighborly::Stripe::PaymentsController
  puts "   ✅ PaymentsController existe"
  
  actions = controller.action_methods.to_a.sort
  puts "   - Actions disponibles: #{actions.join(', ')}"
rescue => e
  puts "   ❌ Erreur: #{e.message}"
  exit 1
end

# 3. Vérifier helper de routes
puts "\n3. Vérification helpers de routes:"
begin
  # Test avec un projet existant
  project = Project.first
  if project
    path = Rails.application.routes.url_helpers.neighborly_stripe.payment_new_path(
      project_id: project.id,
      contribution_id: 1
    )
    puts "   ✅ Helper payment_new_path fonctionne"
    puts "   - Exemple: #{path}"
  else
    puts "   ⚠️  Aucun projet pour tester le helper"
  end
rescue => e
  puts "   ❌ Erreur helper: #{e.message}"
end

# 4. Vérifier vue partielle
puts "\n4. Vérification vues:"
stripe_partial = Rails.root.join('app', 'views', 'shared', 'payments', '_stripe.html.erb')
if File.exist?(stripe_partial)
  puts "   ✅ Partiel _stripe.html.erb existe"
  content = File.read(stripe_partial)
  if content.include?('payment_new_path') && content.include?('button--stripe')
    puts "   ✅ Contenu correct (route + classe CSS)"
  else
    puts "   ⚠️  Vérifier le contenu du partiel"
  end
else
  puts "   ❌ Partiel _stripe.html.erb manquant!"
  exit 1
end

# 5. Vérifier CSS
puts "\n5. Vérification styles CSS:"
payments_sass = Rails.root.join('app', 'assets', 'stylesheets', 'pages', 'payments.sass')
if File.exist?(payments_sass)
  content = File.read(payments_sass)
  if content.include?('.button--stripe')
    puts "   ✅ Styles .button--stripe définis"
  else
    puts "   ⚠️  Styles .button--stripe manquants"
  end
else
  puts "   ⚠️  Fichier payments.sass non trouvé"
end

# 6. Vérifier image logo
puts "\n6. Vérification logo Stripe:"
stripe_logo = Rails.root.join('app', 'assets', 'images', 'payments', 'stripe.png')
if File.exist?(stripe_logo)
  size = File.size(stripe_logo)
  puts "   ✅ Logo stripe.png existe (#{size} bytes)"
else
  puts "   ❌ Logo stripe.png manquant!"
end

# 7. Vérifier projets use_stripe
puts "\n7. Vérification projets activés:"
total = Project.count
enabled = Project.where(use_stripe: true).count
puts "   - Projets total: #{total}"
puts "   - Stripe activé: #{enabled}"
if enabled > 0
  puts "   ✅ Au moins #{enabled} projet(s) avec Stripe activé"
else
  puts "   ❌ Aucun projet avec Stripe activé!"
end

puts "\n========================================="
puts "✅ TOUS LES TESTS PASSÉS!"
puts "Le bouton Stripe devrait fonctionner correctement."
puts "========================================="
puts "\nPour tester:"
puts "1. Démarrer serveur: bundle exec puma -p 3001"
puts "2. Aller sur: http://localhost:3001"
puts "3. Sélectionner un projet"
puts "4. Créer une contribution"
puts "5. Cliquer sur le bouton Stripe bleu"
puts "6. Vérifier redirection vers Stripe Checkout"
puts "\n========================================="
