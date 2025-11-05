require_relative 'config/environment'

puts "=" * 80
puts "🔍 DEBUG LIVE - REWARDS RENDERING"
puts "=" * 80
puts ""

# Simuler le contexte du contrôleur
project = Project.find_by(permalink: 'joro_pay_web')
user = project.user
admin = User.find_by(email: 'admin@fiatope.com')

puts "📋 CONTEXTE"
puts "=" * 80
puts "  Projet       : #{project.name}"
puts "  Propriétaire : #{user.name} (#{user.email})"
puts "  Admin        : #{admin.name} (#{admin.email})"
puts ""

puts "🔐 POLICY CHECKS"
puts "=" * 80

# Simuler policy(parent).update? avec le propriétaire
puts "Avec le PROPRIÉTAIRE (#{user.email}):"
owner_policy = ProjectPolicy.new(user, project)
puts "  policy(project).update? = #{owner_policy.update?}"
puts ""

# Simuler policy(parent).update? avec l'admin
puts "Avec l'ADMIN (#{admin.email}):"
admin_policy = ProjectPolicy.new(admin, project)
puts "  policy(project).update? = #{admin_policy.update?}"
puts ""

puts "📊 DÉTAILS DES VÉRIFICATIONS (Propriétaire)"
puts "=" * 80
puts "  1. is_owned_by?(user)           : #{owner_policy.send(:is_owned_by?, user)}"
puts "  2. is_admin?                    : #{owner_policy.send(:is_admin?)}"
puts "  3. done_by_owner_or_admin?      : #{owner_policy.send(:done_by_owner_or_admin?)}"
puts "  4. is_channel_admin?            : #{owner_policy.send(:is_channel_admin?)}"
puts "  5. create?                      : #{owner_policy.create?}"
puts "  6. update?                      : #{owner_policy.update?}"
puts ""

puts "📊 DÉTAILS DES VÉRIFICATIONS (Admin)"
puts "=" * 80
puts "  1. is_owned_by?(admin)          : #{admin_policy.send(:is_owned_by?, admin)}"
puts "  2. is_admin?                    : #{admin_policy.send(:is_admin?)}"
puts "  3. done_by_owner_or_admin?      : #{admin_policy.send(:done_by_owner_or_admin?)}"
puts "  4. is_channel_admin?            : #{admin_policy.send(:is_channel_admin?)}"
puts "  5. create?                      : #{admin_policy.create?}"
puts "  6. update?                      : #{admin_policy.update?}"
puts ""

puts "🔎 CHANNEL INFO"
puts "=" * 80
if project.last_channel
  channel = project.last_channel
  puts "  Nom         : #{channel.name}"
  puts "  Propriétaire: #{channel.user.name} (#{channel.user.email})"
  puts "  Membres     : #{channel.members.count}"
  
  if channel.members.any?
    puts ""
    puts "  Liste des membres:"
    channel.members.each do |member|
      puts "    - #{member.name} (#{member.email})"
    end
  end
  
  puts ""
  puts "  Vérifications channel:"
  puts "    - channel.user == propriétaire  : #{channel.user.id == user.id}"
  puts "    - channel.user == admin         : #{channel.user.id == admin.id}"
  puts "    - propriétaire dans members?    : #{channel.members.include?(user)}"
  puts "    - admin dans members?           : #{channel.members.include?(admin)}"
else
  puts "  ❌ Pas de channel"
end
puts ""

puts "🎯 DIAGNOSTIC"
puts "=" * 80

if owner_policy.update?
  puts "✅ La policy autorise le propriétaire à update"
  puts "   → Le bouton DEVRAIT s'afficher dans rewards/index.html.slim"
  puts ""
  puts "⚠️  Si le bouton ne s'affiche PAS dans le navigateur:"
  puts "   1. Vérifier que current_user est bien défini"
  puts "   2. Vérifier les logs du serveur Rails"
  puts "   3. Vérifier la console JavaScript (F12)"
  puts "   4. Vérifier que la requête AJAX vers /projects/joro_pay_web/rewards passe"
else
  puts "❌ La policy N'autorise PAS le propriétaire"
  puts "   Raison à investiguer..."
end

puts ""

if admin_policy.update?
  puts "✅ La policy autorise l'admin à update"
else
  puts "❌ La policy N'autorise PAS l'admin"
end

puts ""
puts "=" * 80
puts "💡 TEST DANS LE NAVIGATEUR"
puts "=" * 80
puts ""
puts "1. Va sur : http://localhost:3001/projects/joro_pay_web"
puts "2. Connecte-toi avec : #{user.email}"
puts "3. Ouvre la console JavaScript (F12)"
puts "4. Copie-colle ce code:"
puts ""
puts "   fetch('/projects/joro_pay_web/rewards')"
puts "     .then(r => r.text())"
puts "     .then(html => {"
puts "       console.log('HTML Length:', html.length)"
puts "       console.log('Contains add-reward?', html.includes('add-reward'))"
puts "       console.log('Contains policy?', html.includes('policy'))"
puts "       if (!html.includes('add-reward')) {"
puts "         console.log('❌ LE SERVEUR NE GÉNÈRE PAS LE BOUTON !')"
puts "       } else {"
puts "         console.log('✅ Le serveur génère le bouton')"
puts "       }"
puts "     })"
puts ""
puts "=" * 80
