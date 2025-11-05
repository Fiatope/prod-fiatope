require_relative 'config/environment'

puts "=" * 80
puts "🔧 FIX : ASSIGNER UN CHANNEL AU PROJET"
puts "=" * 80
puts ""

# Trouver tous les projets sans channel
projects_without_channel = Project.where.not(id: Project.joins(:channels).select(:id))

if projects_without_channel.empty?
  puts "✅ Tous les projets ont un channel"
  puts ""
else
  puts "⚠️  #{projects_without_channel.count} projet(s) sans channel trouvé(s) :"
  puts ""
  
  projects_without_channel.each do |p|
    puts "  • #{p.permalink.ljust(30)} - #{p.name}"
  end
  puts ""
end

# Vérifier s'il y a des channels
channels = Channel.all

if channels.empty?
  puts "❌ AUCUN CHANNEL TROUVÉ DANS LA BASE DE DONNÉES !"
  puts ""
  puts "Tu dois créer un channel d'abord :"
  puts ""
  puts "  rails console"
  puts "  channel = Channel.create!("
  puts "    name: 'Canal Principal',"
  puts "    permalink: 'principal',"
  puts "    description: 'Canal par défaut'"
  puts "  )"
  puts ""
  exit 1
end

puts "📋 CHANNELS DISPONIBLES :"
puts "=" * 80
channels.each do |c|
  projects_count = c.projects.count
  puts "  #{c.id.to_s.rjust(3)} - #{c.name.ljust(30)} (#{projects_count} projet(s))"
  puts "      Permalink: #{c.permalink}"
  puts "      Owner: #{c.user&.name || 'Aucun'}"
  puts ""
end

# Demander quel projet fixer
print "Entre le permalink du projet à fixer (ou 'all' pour tous) : "
input = gets.chomp

if input == 'all'
  projects_to_fix = projects_without_channel
else
  begin
    project = Project.find_by_permalink!(input)
    projects_to_fix = [project]
  rescue => e
    puts "❌ Projet non trouvé : #{e.message}"
    exit 1
  end
end

if projects_to_fix.empty?
  puts "✅ Aucun projet à fixer"
  exit 0
end

# Demander quel channel utiliser
print "Entre l'ID du channel à utiliser (ou 'first' pour le premier) : "
channel_input = gets.chomp

if channel_input == 'first'
  channel = channels.first
else
  begin
    channel = Channel.find(channel_input.to_i)
  rescue => e
    puts "❌ Channel non trouvé : #{e.message}"
    exit 1
  end
end

puts ""
puts "🔧 APPLICATION DU FIX"
puts "=" * 80
puts ""

projects_to_fix.each do |project|
  print "  • #{project.permalink.ljust(30)} ... "
  
  begin
    # Vérifier si déjà assigné
    if project.channels.include?(channel)
      puts "⚠️  Déjà assigné"
    else
      project.channels << channel
      project.save!
      puts "✅ OK"
    end
  rescue => e
    puts "❌ ERREUR: #{e.message}"
  end
end

puts ""
puts "=" * 80
puts "✅ FIX TERMINÉ !"
puts "=" * 80
puts ""
puts "#{projects_to_fix.count} projet(s) assigné(s) au channel '#{channel.name}'"
puts ""
puts "Maintenant, relance le test :"
puts "  ruby test_rewards_live.rb"
puts ""
puts "Ou teste directement dans le navigateur :"
puts "  http://localhost:3001/projects/#{projects_to_fix.first.permalink}"
puts ""
puts "=" * 80
