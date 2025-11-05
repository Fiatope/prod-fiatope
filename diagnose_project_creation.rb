require_relative 'config/environment'

puts "=" * 80
puts "🔍 DIAGNOSTIC CRÉATION DE PROJET"
puts "=" * 80
puts ""

# Créer un projet de test pour voir les validations
test_project = Project.new(
  user: User.first,
  campaign_type: :all_or_none
)

puts "📋 Champs requis pour sauvegarder un projet:"
puts ""

# Essayer de sauvegarder et voir les erreurs
unless test_project.save
  puts "❌ Erreurs de validation:"
  test_project.errors.full_messages.each do |error|
    puts "   • #{error}"
  end
  puts ""
  
  puts "📝 Détail des champs manquants:"
  puts ""
  
  required_fields = {
    'name' => test_project.name,
    'user' => test_project.user,
    'category' => test_project.category,
    'about' => test_project.about,
    'headline' => test_project.headline,
    'goal' => test_project.goal,
    'permalink' => test_project.permalink,
    'location' => test_project.location
  }
  
  required_fields.each do |field, value|
    status = value.present? ? "✅" : "❌"
    puts "   #{status} #{field.ljust(20)} : #{value.inspect}"
  end
  
  puts ""
  puts "🔍 Autres attributs du projet:"
  puts "   • online_days: #{test_project.online_days.inspect}"
  puts "   • state: #{test_project.state.inspect}"
  puts "   • video_url: #{test_project.video_url.inspect}"
  puts ""
end

puts "=" * 80
puts "💡 CONSEIL:"
puts "=" * 80
puts ""
puts "Assure-toi que le formulaire de création de projet"
puts "collecte TOUS ces champs obligatoires:"
puts ""
puts "  1. name          - Nom du projet"
puts "  2. user          - Créateur (auto-rempli)"
puts "  3. category      - Catégorie du projet"
puts "  4. about         - Description détaillée"
puts "  5. headline      - Résumé court (max 140 caractères)"
puts "  6. goal          - Objectif de financement"
puts "  7. permalink     - URL (généré automatiquement depuis name)"
puts "  8. location      - Localisation du projet"
puts "  9. online_days   - Durée de la campagne"
puts ""
puts "Pour l'état 'online', il faut aussi:"
puts "  • video_url"
puts "  • address_city"
puts "  • address_state"
puts ""
puts "=" * 80
