require_relative 'config/environment'

puts "=" * 80
puts "🚀 CHECK RAPIDE : POLICY REWARDS"
puts "=" * 80
puts ""

# Prendre le premier projet
project = Project.first

unless project
  puts "❌ Aucun projet dans la base"
  exit 1
end

puts "📊 PROJET TESTÉ"
puts "=" * 80
puts "  Nom          : #{project.name}"
puts "  Permalink    : #{project.permalink}"
puts "  Propriétaire : #{project.user.name} (#{project.user.email})"
puts "  last_channel : #{project.last_channel&.name || '⚠️  NIL ← PROBLÈME !'}"
puts ""

# Tester avec le propriétaire
owner = project.user

puts "👤 TEST AVEC LE PROPRIÉTAIRE DU PROJET"
puts "=" * 80
puts "  Nom   : #{owner.name}"
puts "  Email : #{owner.email}"
puts "  Admin : #{owner.admin? ? '✅ OUI' : '❌ NON'}"
puts ""

# Test ProjectPolicy
project_policy = ProjectPolicy.new(owner, project)

puts "🔐 TESTS POLICY"
puts "=" * 80

# Test is_owned_by
puts "  1. is_owned_by?(owner) :"
puts "     project.user == owner ? #{project.user == owner ? '✅ TRUE' : '❌ FALSE'}"

# Test is_admin
puts ""
puts "  2. is_admin? :"
puts "     owner.admin? ? #{owner.admin? ? '✅ TRUE' : '❌ FALSE'}"

# Test is_channel_admin
puts ""
puts "  3. is_channel_admin? :"
if project.last_channel
  is_channel_admin = (project.last_channel.user == owner) || owner.channels.include?(project.last_channel)
  puts "     → #{is_channel_admin ? '✅ TRUE' : '❌ FALSE'}"
  puts "     Channel: #{project.last_channel.name}"
  puts "     Channel owner: #{project.last_channel.user&.email || 'N/A'}"
else
  puts "     → ⚠️  project.last_channel est NIL"
  puts "     → C'EST PROBABLEMENT LE PROBLÈME !"
  puts ""
  puts "     La méthode is_channel_admin? dans ProjectPolicy (ligne 104) fait :"
  puts "       record.last_channel.try(:user) == user"
  puts ""
  puts "     Si last_channel est nil, try(:user) retourne nil"
  puts "     Donc nil == user retourne FALSE"
end

# Test done_by_owner_or_admin
puts ""
puts "  4. done_by_owner_or_admin? :"
done_by_owner_or_admin = (project.user == owner) || owner.admin?
puts "     → #{done_by_owner_or_admin ? '✅ TRUE' : '❌ FALSE'}"

# Test policy.update?
puts ""
puts "  🎯 RÉSULTAT FINAL :"
puts "     policy(project).update? = #{project_policy.update? ? '✅ TRUE' : '❌ FALSE'}"
puts ""

if project_policy.update?
  puts "✅ LE BOUTON REWARDS DEVRAIT S'AFFICHER"
else
  puts "❌ LE BOUTON REWARDS NE S'AFFICHERA PAS"
  puts ""
  puts "📋 DIAGNOSTIC :"
  
  if !project.last_channel
    puts ""
    puts "🔥 CAUSE : project.last_channel est NIL"
    puts ""
    puts "SOLUTION : Assigner un channel au projet"
    puts ""
    puts "  Option 1 - Script automatique :"
    puts "    ruby fix_project_channel.rb"
    puts ""
    puts "  Option 2 - Manuellement :"
    puts "    rails console"
    puts "    project = Project.find_by_permalink('#{project.permalink}')"
    puts "    channel = Channel.first"
    puts "    project.channels << channel"
    puts "    project.save"
    puts ""
  elsif !owner.admin? && project.user != owner
    puts ""
    puts "CAUSE : L'utilisateur n'est ni propriétaire ni admin"
    puts ""
  else
    puts ""
    puts "CAUSE : Inconnue, vérifier les logs"
  end
end

# Vérifier tous les projets
puts ""
puts "=" * 80
puts "📊 STATISTIQUES GLOBALES"
puts "=" * 80

all_projects = Project.all
projects_without_channel = Project.where.not(id: Project.joins(:channels).select(:id))

puts "  Total projets          : #{all_projects.count}"
puts "  Projets sans channel   : #{projects_without_channel.count}"

if projects_without_channel.any?
  puts ""
  puts "  ⚠️  Projets affectés (sans bouton rewards) :"
  projects_without_channel.limit(10).each do |p|
    puts "     • #{p.permalink}"
  end
  
  if projects_without_channel.count > 10
    puts "     ... et #{projects_without_channel.count - 10} autre(s)"
  end
end

puts ""
puts "=" * 80
puts "💡 PROCHAINE ÉTAPE"
puts "=" * 80
puts ""

if projects_without_channel.any?
  puts "Lance le fix pour assigner des channels :"
  puts "  ruby fix_project_channel.rb"
else
  puts "Tous les projets ont un channel."
  puts "Si le bouton ne s'affiche toujours pas, vérifie :"
  puts "  1. Que tu es connecté avec le bon utilisateur"
  puts "  2. Les logs JavaScript dans le navigateur (F12)"
  puts "  3. La réponse de la requête AJAX /projects/:id/rewards"
end

puts ""
puts "=" * 80
