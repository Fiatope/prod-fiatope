require_relative 'config/environment'

puts "=" * 80
puts "🧪 TEST : RENDU DE LA VUE REWARDS"
puts "=" * 80
puts ""

# Contexte
project = Project.find_by(permalink: 'joro_pay_web')
user = project.user
rewards = project.rewards.rank(:row_order)

puts "📋 CONTEXTE"
puts "=" * 80
puts "  Projet  : #{project.name}"
puts "  User    : #{user.name} (#{user.email})"
puts "  Rewards : #{rewards.count}"
puts ""

# Simuler le contexte de la vue
class FakeView
  include ActionView::Helpers
  include Pundit
  
  attr_accessor :current_user
  
  def initialize(user)
    @current_user = user
  end
  
  def policy(record)
    Pundit.policy!(current_user, record)
  end
end

view_context = FakeView.new(user)

puts "🔐 TEST POLICY DANS LE CONTEXTE DE LA VUE"
puts "=" * 80

begin
  policy_result = view_context.policy(project).update?
  puts "  policy(project).update? = #{policy_result}"
  
  if policy_result
    puts ""
    puts "  ✅ La policy retourne TRUE"
    puts "  → Le bloc '- if policy(parent).update?' DEVRAIT s'exécuter"
    puts "  → Le bouton .add-reward DEVRAIT être rendu"
  else
    puts ""
    puts "  ❌ La policy retourne FALSE"
    puts "  → Le bloc '- if policy(parent).update?' NE s'exécutera PAS"
    puts "  → Le bouton .add-reward NE sera PAS rendu"
  end
rescue => e
  puts "  ❌ ERREUR lors de l'appel à policy()"
  puts "     #{e.class}: #{e.message}"
  puts ""
  puts "     Cela signifie que policy() ne fonctionne pas dans la vue"
end

puts ""

# Test avec current_user = nil
puts "🔐 TEST AVEC current_user = NIL (non connecté)"
puts "=" * 80

view_context_nil = FakeView.new(nil)

begin
  policy_result_nil = view_context_nil.policy(project).update?
  puts "  policy(project).update? = #{policy_result_nil}"
  
  if policy_result_nil
    puts "  ✅ Retourne TRUE (surprenant !)"
  else
    puts "  ❌ Retourne FALSE"
    puts "  → C'est NORMAL : utilisateur non connecté = pas de permission"
  end
rescue => e
  puts "  ❌ ERREUR (normal si user = nil)"
  puts "     #{e.class}: #{e.message}"
end

puts ""
puts "=" * 80
puts "💡 DIAGNOSTIC"
puts "=" * 80
puts ""

if policy_result
  puts "La policy fonctionne côté serveur."
  puts ""
  puts "Si le bouton ne s'affiche PAS dans le navigateur, le problème est:"
  puts ""
  puts "1️⃣  current_user est NIL dans la requête AJAX"
  puts "   → Solution: Vérifier l'authentification"
  puts ""
  puts "2️⃣  Le JavaScript ne charge pas la section rewards"
  puts "   → Solution: Vérifier la console JavaScript (F12)"
  puts ""
  puts "3️⃣  La réponse AJAX est vide ou incomplète"
  puts "   → Solution: Vérifier les logs du serveur Rails"
  puts ""
  puts "📍 PROCHAINE ÉTAPE : Teste dans le navigateur"
  puts ""
  puts "1. Va sur http://localhost:3001/projects/joro_pay_web"
  puts "2. Connecte-toi avec: #{user.email}"
  puts "3. Ouvre la console (F12) et copie-colle:"
  puts ""
  puts "   fetch('/projects/joro_pay_web/rewards')"
  puts "     .then(r => r.text())"
  puts "     .then(html => {"
  puts "       console.log('Contient add-reward?', html.includes('add-reward'))"
  puts "       if (!html.includes('add-reward')) {"
  puts "         console.log('❌ SERVEUR NE GÉNÈRE PAS LE BOUTON')"
  puts "         console.log('Réponse:', html.substring(0, 500))"
  puts "       }"
  puts "     })"
  puts ""
else
  puts "❌ La policy ne fonctionne pas correctement"
  puts "   Vérifier les permissions du projet et du channel"
end

puts "=" * 80
