require_relative 'config/environment'

puts "=" * 80
puts "🔧 CRÉATION DU CANAL PAR DÉFAUT"
puts "=" * 80
puts ""

# Vérifier s'il existe déjà
existing = Channel.find_by(permalink: 'general')

if existing
  puts "✅ Le canal 'Général' existe déjà"
  puts "   Nom: #{existing.name}"
  puts "   Propriétaire: #{existing.user.name} (#{existing.user.email})"
  puts ""
  puts "Rien à faire. Lancez maintenant :"
  puts "  ruby fix_all_projects_channels.rb"
  puts ""
  puts "=" * 80
  exit 0
end

# Trouver un admin
admin = User.find_by(email: 'admin@fiatope.com') || User.where(admin: true).first

unless admin
  puts "❌ Aucun administrateur trouvé"
  puts ""
  puts "Créez d'abord un admin avec :"
  puts "  ruby create_admin.rb"
  puts ""
  exit 1
end

puts "👤 Propriétaire du canal : #{admin.name} (#{admin.email})"
puts ""

# Créer le canal
print "Création du canal 'Général'... "

begin
  channel = Channel.new(
    name: 'Général',
    permalink: 'general',
    description: 'Canal par défaut pour tous les projets'
  )
  
  # Assigner l'admin comme propriétaire
  channel.user = admin
  
  # Sauvegarder
  channel.save!
  
  puts "✅ OK"
  puts ""
  puts "=" * 80
  puts "✅ CANAL CRÉÉ AVEC SUCCÈS"
  puts "=" * 80
  puts ""
  puts "  ID         : #{channel.id}"
  puts "  Nom        : #{channel.name}"
  puts "  Permalink  : #{channel.permalink}"
  puts "  Propriétaire : #{admin.name}"
  puts ""
  puts "💡 PROCHAINE ÉTAPE :"
  puts "   ruby fix_all_projects_channels.rb"
  puts ""
  puts "=" * 80
  
rescue => e
  puts "❌ ERREUR"
  puts ""
  puts "Message : #{e.message}"
  puts ""
  
  if e.message.include?("phone")
    puts "Le canal nécessite un numéro de téléphone pour l'utilisateur."
    puts ""
    puts "Solution rapide :"
    puts "  rails console"
    puts "  admin = User.find(#{admin.id})"
    puts "  admin.update(phone_number: '+33600000000')  # Mettez un vrai numéro"
    puts ""
    puts "Puis relancez ce script."
  end
  
  puts "=" * 80
  exit 1
end
