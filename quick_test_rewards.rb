require_relative 'config/environment'

puts "=" * 80
puts "🚀 TEST RAPIDE : BOUTON REWARDS"
puts "=" * 80
puts ""

# Test avec l'admin
admin = User.find_by(email: 'admin@fiatope.com')

unless admin
  puts "❌ Admin non trouvé (admin@fiatope.com)"
  puts "Crée d'abord un admin avec create_admin.rb"
  exit 1
end

puts "✅ Admin trouvé : #{admin.name} (#{admin.email})"
puts ""

# Liste des projets
projects = Project.all.limit(5)

if projects.empty?
  puts "❌ Aucun projet dans la base de données"
  exit 1
end

puts "📋 PROJETS DISPONIBLES (5 premiers)"
puts "=" * 80
projects.each do |p|
  owner_badge = (p.user == admin) ? " [TU ES PROPRIÉTAIRE]" : ""
  admin_badge = admin.admin? ? " [TU ES ADMIN]" : ""
  puts "  • #{p.permalink.ljust(30)} - #{p.name}#{owner_badge}#{admin_badge}"
end
puts ""

# Test pour chaque projet
puts "🔍 TEST DES PERMISSIONS POUR CHAQUE PROJET"
puts "=" * 80
puts ""

projects.each do |project|
  puts "📊 Projet : #{project.name} (#{project.permalink})"
  puts "   Propriétaire : #{project.user.name}"
  puts ""
  
  # Test avec l'admin
  reward = Reward.new(project: project)
  policy = RewardPolicy.new(admin, reward)
  
  can_update = policy.update?
  
  if can_update
    puts "   ✅ Admin PEUT ajouter des rewards"
    puts "   → Le bouton DEVRAIT s'afficher sur /projects/#{project.permalink}"
  else
    puts "   ❌ Admin NE PEUT PAS ajouter des rewards"
    puts "   → Le bouton NE s'affichera PAS"
    puts "   → PROBLÈME DÉTECTÉ !"
  end
  
  puts ""
end

puts "=" * 80
puts "💡 POUR TESTER DANS LE NAVIGATEUR"
puts "=" * 80
puts ""
puts "1. Lance le serveur :"
puts "   ruby bin/rails server -p 3001"
puts ""
puts "2. Connecte-toi avec :"
puts "   Email    : admin@fiatope.com"
puts "   Password : admin123"
puts ""
puts "3. Va sur un projet :"
puts "   http://localhost:3001/projects/#{projects.first.permalink}"
puts ""
puts "4. Le bouton 'Ajouter reward' DOIT être visible en bas à droite"
puts ""
puts "=" * 80
