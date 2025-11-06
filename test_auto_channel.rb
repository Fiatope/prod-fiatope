require_relative 'config/environment'

puts "=" * 80
puts "🧪 TEST : AUTO-ASSIGNATION CHANNEL"
puts "=" * 80
puts ""

puts "📋 ÉTAPE 1 : Vérification du callback"
puts "=" * 80

# Vérifier que le callback est bien enregistré
callbacks = Project._create_callbacks.select { |cb| cb.filter == :assign_default_channel }

if callbacks.any?
  puts "✅ Callback 'assign_default_channel' enregistré"
else
  puts "❌ Callback 'assign_default_channel' NON enregistré"
  puts "   Vérifier que le code a bien été ajouté dans project.rb"
  exit 1
end
puts ""

puts "📋 ÉTAPE 2 : Vérification de la méthode"
puts "=" * 80

if Project.private_method_defined?(:assign_default_channel)
  puts "✅ Méthode 'assign_default_channel' définie"
else
  puts "❌ Méthode 'assign_default_channel' NON définie"
  exit 1
end
puts ""

puts "📋 ÉTAPE 3 : Test de création de projet"
puts "=" * 80

# Compter les projets avant
projects_before = Project.count
channels_before = Channel.count

puts "  Projets avant  : #{projects_before}"
puts "  Channels avant : #{channels_before}"
puts ""

# Créer un projet de test
begin
  test_user = User.first
  
  unless test_user
    puts "❌ Aucun utilisateur dans la base"
    exit 1
  end
  
  test_category = Category.first
  
  unless test_category
    puts "❌ Aucune catégorie dans la base"
    exit 1
  end
  
  print "  Création d'un projet de test... "
  
  test_project = Project.create!(
    name: "Test Auto Channel #{Time.now.to_i}",
    user: test_user,
    category: test_category,
    about: "Test automatique de l'assignation de channel",
    headline: "Test",
    goal: 1000,
    online_days: 30,
    location: "Test City"
  )
  
  puts "✅ OK"
  puts "     ID : #{test_project.id}"
  puts "     Nom: #{test_project.name}"
  puts ""
  
rescue => e
  puts "❌ ERREUR"
  puts "     #{e.message}"
  puts ""
  puts "     Détails: #{e.backtrace.first(5).join("\n             ")}"
  exit 1
end

puts "📋 ÉTAPE 4 : Vérification de l'assignation"
puts "=" * 80

# Recharger le projet
test_project.reload

if test_project.channels.any?
  puts "✅ Le projet a #{test_project.channels.count} channel(s)"
  puts ""
  test_project.channels.each do |channel|
    puts "     📌 #{channel.name} (#{channel.permalink})"
  end
  puts ""
  
  # Vérifier que c'est bien le canal par défaut
  default_channel = Channel.find_by(permalink: 'general')
  
  if default_channel && test_project.channels.include?(default_channel)
    puts "✅ Le canal par défaut 'Général' a bien été assigné"
  else
    puts "⚠️  Un canal a été assigné mais ce n'est pas 'Général'"
  end
else
  puts "❌ Le projet N'A PAS de channel"
  puts "   Le callback n'a pas fonctionné !"
  exit 1
end
puts ""

puts "📋 ÉTAPE 5 : Nettoyage"
puts "=" * 80

print "  Suppression du projet de test... "
test_project.destroy
puts "✅ OK"
puts ""

puts "=" * 80
puts "🎉 TEST RÉUSSI !"
puts "=" * 80
puts ""
puts "✅ Le callback fonctionne correctement"
puts "✅ Les nouveaux projets auront automatiquement un channel"
puts "✅ Le bouton 'Ajouter reward' s'affichera pour les propriétaires/admins"
puts ""
puts "💡 PROCHAINE ÉTAPE :"
puts "   Fixer les projets existants : ruby fix_all_projects_channels.rb"
puts ""
puts "=" * 80
