require_relative 'config/environment'

puts "=" * 80
puts "🧪 TEST : PAGE PROJET + BOUTON REWARDS"
puts "=" * 80
puts ""

# Trouver le projet
project = Project.find_by(permalink: 'joro_pay_web')

unless project
  puts "❌ Projet 'joro_pay_web' introuvable"
  exit 1
end

puts "📋 PROJET"
puts "=" * 80
puts "  Nom          : #{project.name}"
puts "  Permalink    : #{project.permalink}"
puts "  Propriétaire : #{project.user.name} (#{project.user.email})"
puts ""

puts "📡 CHANNEL"
puts "=" * 80
if project.last_channel
  puts "  ✅ Canal assigné : #{project.last_channel.name}"
  puts "     ID         : #{project.last_channel.id}"
  puts "     Permalink  : #{project.last_channel.permalink}"
  puts "     Image      : #{project.last_channel.image.present? ? '✅ Présente' : '❌ Absente'}"
else
  puts "  ❌ Aucun canal"
end
puts ""

puts "🔐 PERMISSIONS"
puts "=" * 80

# Tester avec le propriétaire
owner = project.user
policy = ProjectPolicy.new(owner, project)

puts "  Propriétaire : #{owner.name}"
puts "  - is_owned_by?         : #{policy.send(:is_owned_by?, owner) ? '✅' : '❌'}"
puts "  - done_by_owner_or_admin? : #{policy.send(:done_by_owner_or_admin?) ? '✅' : '❌'}"
puts "  - update?              : #{policy.update? ? '✅' : '❌'}"
puts ""

# Tester avec l'admin si différent
admin = User.find_by(email: 'admin@fiatope.com')
if admin && admin.id != owner.id
  admin_policy = ProjectPolicy.new(admin, project)
  puts "  Admin : #{admin.name}"
  puts "  - is_admin?            : #{admin_policy.send(:is_admin?) ? '✅' : '❌'}"
  puts "  - done_by_owner_or_admin? : #{admin_policy.send(:done_by_owner_or_admin?) ? '✅' : '❌'}"
  puts "  - update?              : #{admin_policy.update? ? '✅' : '❌'}"
  puts ""
end

puts "🎯 RÉSULTAT"
puts "=" * 80

if project.last_channel
  puts "✅ Le projet a un canal"
else
  puts "❌ Le projet n'a PAS de canal"
end

if policy.update?
  puts "✅ Le bouton 'Ajouter reward' DEVRAIT s'afficher pour le propriétaire"
else
  puts "❌ Le bouton 'Ajouter reward' NE S'AFFICHERA PAS"
end

if project.last_channel && !project.last_channel.image.present?
  puts "⚠️  Le canal n'a pas d'image (pas d'erreur mais pas de section 'Partenariat')"
end

puts ""
puts "💡 PROCHAINE ÉTAPE"
puts "=" * 80
puts "  1. Va sur : http://localhost:3001/projects/joro_pay_web"
puts "  2. Connecte-toi avec : #{owner.email}"
puts "  3. Vérifie que le bouton '➕ Ajouter une contrepartie' est visible"
puts ""
puts "=" * 80
