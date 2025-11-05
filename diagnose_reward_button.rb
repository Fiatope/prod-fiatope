require_relative 'config/environment'

puts "=" * 80
puts "🔍 DIAGNOSTIC BOUTON 'AJOUTER REWARD'"
puts "=" * 80
puts ""

# Demander le permalink du projet
print "Entre le permalink du projet (ex: joro_pay_web) : "
permalink = gets.chomp

# Trouver le projet
begin
  project = Project.find_by_permalink!(permalink)
rescue => e
  puts "❌ Projet non trouvé : #{e.message}"
  exit 1
end

puts ""
puts "📊 INFORMATIONS DU PROJET"
puts "=" * 80
puts "  Nom          : #{project.name}"
puts "  Permalink    : #{project.permalink}"
puts "  Propriétaire : #{project.user.name} (#{project.user.email})"
puts "  ID Owner     : #{project.user.id}"
puts "  État         : #{project.state}"
puts "  Channel      : #{project.last_channel&.name || 'Aucun'}"
puts ""

# Demander l'utilisateur
puts "📋 UTILISATEURS DISPONIBLES"
puts "=" * 80
User.all.each do |u|
  admin_badge = u.admin? ? " [ADMIN]" : ""
  puts "  #{u.id.to_s.rjust(3)} - #{u.email.ljust(35)} #{u.name}#{admin_badge}"
end
puts ""

print "Entre l'ID de l'utilisateur à tester : "
user_id = gets.chomp.to_i

begin
  user = User.find(user_id)
rescue => e
  puts "❌ Utilisateur non trouvé : #{e.message}"
  exit 1
end

puts ""
puts "👤 UTILISATEUR TESTÉ"
puts "=" * 80
puts "  ID    : #{user.id}"
puts "  Email : #{user.email}"
puts "  Nom   : #{user.name}"
puts "  Admin : #{user.admin? ? '✅ OUI' : '❌ NON'}"
puts ""

# Test des conditions Policy
puts "🔐 VÉRIFICATION DES PERMISSIONS"
puts "=" * 80

# 1. Est propriétaire ?
is_owner = (project.user == user)
puts "  1️⃣  Propriétaire du projet ? #{is_owner ? '✅ OUI' : '❌ NON'}"
puts "     → project.user.id = #{project.user.id}"
puts "     → current_user.id = #{user.id}"
puts ""

# 2. Est admin ?
is_admin = user.admin?
puts "  2️⃣  Admin de la plateforme ? #{is_admin ? '✅ OUI' : '❌ NON'}"
puts "     → user.admin? = #{user.admin?}"
puts ""

# 3. Est admin du channel ?
is_channel_admin = false
if project.last_channel
  is_channel_admin = (project.last_channel.user == user) || user.channels.include?(project.last_channel)
  puts "  3️⃣  Admin du channel ? #{is_channel_admin ? '✅ OUI' : '❌ NON'}"
  puts "     → Channel: #{project.last_channel.name}"
  puts "     → Channel user: #{project.last_channel.user&.email || 'N/A'}"
  puts "     → User channels: #{user.channels.map(&:name).join(', ')}"
else
  puts "  3️⃣  Admin du channel ? ⚠️  AUCUN CHANNEL"
end
puts ""

# Test de la policy réelle
puts "🎯 TEST POLICY RÉEL"
puts "=" * 80

# Créer un reward fictif pour tester
reward = Reward.new(project: project)
policy = RewardPolicy.new(user, reward)

can_create = policy.create?
can_update = policy.update?

puts "  policy(reward).create? = #{can_create ? '✅ TRUE' : '❌ FALSE'}"
puts "  policy(reward).update? = #{can_update ? '✅ TRUE' : '❌ FALSE'}"
puts ""

# Résumé final
puts "=" * 80
puts "📊 RÉSUMÉ"
puts "=" * 80
puts ""

if can_update
  puts "✅ LE BOUTON 'AJOUTER REWARD' DEVRAIT S'AFFICHER"
  puts ""
  puts "L'utilisateur #{user.name} peut ajouter des rewards car :"
  reasons = []
  reasons << "• Il est propriétaire du projet" if is_owner
  reasons << "• Il est admin de la plateforme" if is_admin
  reasons << "• Il est admin du channel" if is_channel_admin
  puts reasons.join("\n")
else
  puts "❌ LE BOUTON 'AJOUTER REWARD' NE S'AFFICHE PAS"
  puts ""
  puts "L'utilisateur #{user.name} ne peut PAS ajouter de rewards car :"
  puts "  ❌ Il n'est PAS propriétaire du projet (#{project.user.name})"
  puts "  ❌ Il n'est PAS admin de la plateforme"
  puts "  ❌ Il n'est PAS admin du channel" if project.last_channel
  puts ""
  puts "💡 SOLUTIONS POSSIBLES:"
  puts ""
  puts "1. Connecte-toi avec le compte du propriétaire:"
  puts "   Email : #{project.user.email}"
  puts ""
  puts "2. Connecte-toi avec un compte admin:"
  admin_users = User.where(admin: true)
  if admin_users.any?
    admin_users.each do |admin|
      puts "   Email : #{admin.email}"
    end
  else
    puts "   ⚠️  Aucun admin trouvé dans la base"
  end
  puts ""
  puts "3. Donne les droits admin à l'utilisateur actuel:"
  puts "   rails console"
  puts "   user = User.find(#{user.id})"
  puts "   user.update(admin: true)"
end

puts ""
puts "=" * 80
