require_relative 'config/environment'

puts "=" * 80
puts "🔧 MIGRATION : AUTO-ASSIGNATION CHANNELS"
puts "=" * 80
puts ""

# Compter les projets sans channel
projects_without_channel = Project.where.not(id: Project.joins(:channels).select(:id))
total_projects = Project.count

puts "📊 STATISTIQUES"
puts "=" * 80
puts "  Total projets          : #{total_projects}"
puts "  Projets sans channel   : #{projects_without_channel.count}"
puts "  Projets avec channel   : #{total_projects - projects_without_channel.count}"
puts ""

if projects_without_channel.empty?
  puts "✅ Tous les projets ont déjà un channel !"
  puts ""
  puts "=" * 80
  exit 0
end

puts "📋 PROJETS À CORRIGER"
puts "=" * 80
projects_without_channel.each do |p|
  puts "  • #{p.permalink.ljust(30)} - #{p.name}"
end
puts ""

print "Voulez-vous corriger ces #{projects_without_channel.count} projet(s) ? (oui/non) : "
confirmation = gets.chomp.downcase

unless ['oui', 'o', 'yes', 'y'].include?(confirmation)
  puts "❌ Opération annulée"
  exit 0
end

puts ""
puts "🚀 CORRECTION EN COURS..."
puts "=" * 80
puts ""

# Trouver un canal existant (préférence pour 'general' ou le premier disponible)
default_channel = Channel.find_by(permalink: 'general') || Channel.first

unless default_channel
  puts "❌ AUCUN CANAL TROUVÉ DANS LA BASE DE DONNÉES"
  puts ""
  puts "Vous devez d'abord créer un canal manuellement :"
  puts ""
  puts "  1. Connectez-vous en admin"
  puts "  2. Allez sur http://localhost:3001/admin/channels"
  puts "  3. Créez un nouveau canal (ex: 'Général')"
  puts "  4. Relancez ce script"
  puts ""
  puts "Ou utilisez la console Rails :"
  puts ""
  puts "  rails console"
  puts "  admin = User.find_by(admin: true)"
  puts "  Channel.create!(name: 'Général', permalink: 'general', description: 'Canal par défaut', user: admin)"
  puts ""
  exit 1
end

puts "✅ Canal par défaut: '#{default_channel.name}' (ID: #{default_channel.id})"
puts ""

# Corriger chaque projet
success_count = 0
error_count = 0

projects_without_channel.each do |project|
  print "  • #{project.permalink.ljust(30)} ... "
  
  begin
    project.channels << default_channel
    project.save!
    puts "✅ OK"
    success_count += 1
  rescue => e
    puts "❌ ERREUR: #{e.message}"
    error_count += 1
  end
end

puts ""
puts "=" * 80
puts "📊 RÉSULTAT"
puts "=" * 80
puts "  ✅ Corrigés avec succès : #{success_count}"
puts "  ❌ Erreurs              : #{error_count}"
puts ""

if error_count == 0
  puts "🎉 MIGRATION TERMINÉE AVEC SUCCÈS !"
  puts ""
  puts "Tous les projets sont maintenant reliés au canal '#{default_channel.name}'"
  puts ""
  puts "💡 À partir de maintenant :"
  puts "   → Tous les NOUVEAUX projets seront automatiquement reliés à ce canal"
  puts "   → Le bouton 'Ajouter reward' s'affichera pour tous les propriétaires/admins"
else
  puts "⚠️  MIGRATION TERMINÉE AVEC DES ERREURS"
  puts ""
  puts "Vérifiez les erreurs ci-dessus et relancez le script si nécessaire"
end

puts ""
puts "=" * 80
