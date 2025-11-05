require_relative 'config/environment'
require 'open-uri'

puts "=" * 80
puts "🔥 DIAGNOSTIC LIVE : BOUTON REWARDS"
puts "=" * 80
puts ""

# Demander le projet
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
puts "📊 PROJET"
puts "=" * 80
puts "  Nom          : #{project.name}"
puts "  Permalink    : #{project.permalink}"
puts "  Propriétaire : #{project.user.name} (#{project.user.email})"
puts "  État         : #{project.state}"
puts "  Online?      : #{project.online?}"
puts ""

# Demander l'utilisateur
print "Entre l'email de l'utilisateur connecté : "
user_email = gets.chomp

begin
  user = User.find_by_email!(user_email)
rescue => e
  puts "❌ Utilisateur non trouvé : #{e.message}"
  exit 1
end

puts ""
puts "👤 UTILISATEUR"
puts "=" * 80
puts "  Nom   : #{user.name}"
puts "  Email : #{user.email}"
puts "  Admin : #{user.admin? ? '✅ OUI' : '❌ NON'}"
puts ""

# Test de la policy PROJECT
puts "🔐 TEST POLICY PROJECT"
puts "=" * 80
project_policy = ProjectPolicy.new(user, project)
can_update_project = project_policy.update?
puts "  policy(project).update? = #{can_update_project ? '✅ TRUE' : '❌ FALSE'}"
puts ""

# Test de la policy REWARD
puts "🔐 TEST POLICY REWARD"
puts "=" * 80
reward = Reward.new(project: project)
reward_policy = RewardPolicy.new(user, reward)

# Test des méthodes de la policy
puts "  1️⃣  is_owned_by?(user) :"
is_owner = (project.user == user)
puts "     → #{is_owner ? '✅ TRUE' : '❌ FALSE'} (project.user == user)"

puts ""
puts "  2️⃣  is_admin? :"
is_admin = user.admin?
puts "     → #{is_admin ? '✅ TRUE' : '❌ FALSE'} (user.admin?)"

puts ""
puts "  3️⃣  is_channel_admin? :"
if project.last_channel
  is_channel_admin = (project.last_channel.user == user) || user.channels.include?(project.last_channel)
  puts "     → #{is_channel_admin ? '✅ TRUE' : '❌ FALSE'}"
  puts "     → Channel: #{project.last_channel.name}"
  puts "     → Channel owner: #{project.last_channel.user&.email || 'N/A'}"
else
  puts "     → ⚠️  PAS DE CHANNEL (last_channel = nil)"
  puts "     → C'EST LE PROBLÈME !"
end

puts ""
puts "  4️⃣  done_by_owner_or_admin? :"
done_by_owner_or_admin = is_owner || is_admin
puts "     → #{done_by_owner_or_admin ? '✅ TRUE' : '❌ FALSE'}"

puts ""
puts "  🎯 RÉSULTAT FINAL :"
can_create = reward_policy.create?
can_update = reward_policy.update?
puts "     policy(reward).create? = #{can_create ? '✅ TRUE' : '❌ FALSE'}"
puts "     policy(reward).update? = #{can_update ? '✅ TRUE' : '❌ FALSE'}"
puts ""

# Simuler la vue
puts "=" * 80
puts "🖥️  SIMULATION DE LA VUE projects/show.html.slim"
puts "=" * 80
puts ""
puts "section.rewards["
puts "  data-rewards-path=\"/projects/#{project.permalink}/rewards\""
puts "  data-can-update=\"#{project_policy.update?}\""  # ← ICI LE PROBLÈME
puts "]"
puts ""

if project_policy.update?
  puts "✅ data-can-update='true' → JavaScript activera le tri"
else
  puts "❌ data-can-update='false' → JavaScript n'activera PAS le tri"
end
puts ""

# Simuler le contrôleur RewardsController#index
puts "=" * 80
puts "🎮 SIMULATION DU CONTRÔLEUR RewardsController#index"
puts "=" * 80
puts ""
puts "  @rewards = parent.rewards.rank(:row_order)"
rewards = project.rewards.rank(:row_order)
puts "  → #{rewards.count} reward(s) trouvé(s)"
puts ""

if rewards.any?
  rewards.each_with_index do |r, i|
    puts "    #{i+1}. #{r.title} (#{r.minimum_value} EUR)"
  end
else
  puts "    ⚠️  Aucun reward existant"
end
puts ""

# Simuler la vue rewards/index.html.slim
puts "=" * 80
puts "🖥️  SIMULATION DE LA VUE rewards/index.html.slim"
puts "=" * 80
puts ""
puts "Ligne 857 : - if policy(parent).update?"
puts "            → parent = #{project.inspect[0..60]}..."
puts ""

# C'est ICI le problème : on teste policy(parent).update? où parent = project
parent_policy = ProjectPolicy.new(user, project)
parent_can_update = parent_policy.update?

puts "  policy(parent).update? = policy(project).update?"
puts "  → #{parent_can_update ? '✅ TRUE' : '❌ FALSE'}"
puts ""

if parent_can_update
  puts "✅ LE BOUTON .add-reward SERA RENDU DANS LE HTML"
  puts ""
  puts "  <div class='reward add-reward'>"
  puts "    <a href='/projects/#{project.permalink}/rewards/new'>"
  puts "      <i class='icon-et-plus'></i>"
  puts "      <br/>"
  puts "      Ajouter une contrepartie"
  puts "    </a>"
  puts "  </div>"
else
  puts "❌ LE BOUTON .add-reward NE SERA PAS RENDU DANS LE HTML"
  puts ""
  puts "  Le code 'if policy(parent).update?' sur la ligne 857 retourne FALSE"
  puts "  Donc la section .add-reward n'est jamais générée."
end
puts ""

# DIAGNOSTIC FINAL
puts "=" * 80
puts "🎯 DIAGNOSTIC FINAL"
puts "=" * 80
puts ""

if parent_can_update
  puts "✅ LA POLICY FONCTIONNE CORRECTEMENT"
  puts ""
  puts "Le bouton DEVRAIT s'afficher. Si ce n'est pas le cas, vérifiez :"
  puts ""
  puts "1. 🌐 DANS LE NAVIGATEUR (F12 → Console) :"
  puts "   document.querySelector('.rewards')"
  puts "   → Doit retourner un élément HTML"
  puts ""
  puts "2. 🌐 VÉRIFIER L'APPEL AJAX :"
  puts "   Onglet Network → Chercher '/projects/#{project.permalink}/rewards'"
  puts "   → Regarder la réponse HTML"
  puts "   → Elle DOIT contenir '<div class=\"reward add-reward\">' ou '.add-reward'"
  puts ""
  puts "3. 🌐 VÉRIFIER SI LE BOUTON EST PRÉSENT MAIS CACHÉ :"
  puts "   document.querySelector('.add-reward')"
  puts "   → Si retourne un élément, le bouton existe mais est peut-être caché par CSS"
  puts ""
  puts "4. 🔄 RECHARGER LA PAGE AVEC Ctrl+Shift+R (vidage du cache)"
  puts ""
  puts "5. 📜 VÉRIFIER LES ERREURS JAVASCRIPT :"
  puts "   Console → Regarder s'il y a des erreurs en rouge"
else
  puts "❌ LA POLICY BLOQUE L'AFFICHAGE DU BOUTON"
  puts ""
  puts "CAUSE : policy(project).update? retourne FALSE"
  puts ""
  puts "VÉRIFICATIONS :"
  puts "  ✓ Propriétaire du projet ? #{is_owner ? '✅' : '❌'}"
  puts "  ✓ Admin plateforme ?       #{is_admin ? '✅' : '❌'}"
  puts "  ✓ Admin du channel ?       #{project.last_channel ? (is_channel_admin ? '✅' : '❌') : '⚠️  PAS DE CHANNEL'}"
  puts ""
  
  if !project.last_channel
    puts "🔥 PROBLÈME IDENTIFIÉ : LE PROJET N'A PAS DE CHANNEL !"
    puts ""
    puts "Le projet.last_channel est NIL, ce qui cause un problème dans la policy."
    puts ""
    puts "SOLUTION 1 : Assigner un channel au projet"
    puts ""
    puts "  rails console"
    puts "  project = Project.find_by_permalink('#{project.permalink}')"
    puts "  channel = Channel.first  # ou un channel spécifique"
    puts "  project.channels << channel"
    puts "  project.save"
    puts ""
    puts "SOLUTION 2 : Devenir admin"
    puts ""
    puts "  rails console"
    puts "  user = User.find_by_email('#{user.email}')"
    puts "  user.update(admin: true)"
    puts ""
  else
    puts "💡 SOLUTION : Donne les droits à l'utilisateur"
    puts ""
    puts "Option 1 - Devenir admin :"
    puts "  rails console"
    puts "  user = User.find_by_email('#{user.email}')"
    puts "  user.update(admin: true)"
    puts ""
    puts "Option 2 - Connecte-toi avec le propriétaire :"
    puts "  Email : #{project.user.email}"
  end
end

puts ""
puts "=" * 80
