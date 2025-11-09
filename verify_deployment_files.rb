#!/usr/bin/env ruby

puts "=" * 80
puts "🔍 VÉRIFICATION DES FICHIERS DE DÉPLOIEMENT"
puts "=" * 80
puts ""

files_to_check = {
  'Aptfile' => {
    required: true,
    description: 'Dépendances système Linux',
    content_check: ['build-essential', 'imagemagick', 'libpq-dev']
  },
  '.buildpacks' => {
    required: true,
    description: 'Configuration buildpacks Heroku',
    content_check: ['heroku-buildpack-apt', 'heroku-buildpack-nodejs', 'heroku-buildpack-ruby']
  },
  '.node-version' => {
    required: true,
    description: 'Version Node.js',
    content_check: ['18']
  },
  '.profile' => {
    required: true,
    description: 'Configuration environnement',
    content_check: ['Xvfb', 'DISPLAY']
  },
  'app.json' => {
    required: false,
    description: 'Configuration application (optionnel)',
    content_check: ['buildpacks']
  },
  'Procfile' => {
    required: true,
    description: 'Processes web et worker',
    content_check: ['web:', 'worker:']
  },
  'Gemfile' => {
    required: true,
    description: 'Gems Ruby',
    content_check: ['rails', 'pg', 'puma']
  },
  'Gemfile.lock' => {
    required: true,
    description: 'Dépendances verrouillées',
    content_check: ['x86_64-linux']
  }
}

all_ok = true
missing_files = []
invalid_files = []

files_to_check.each do |filename, config|
  print "Vérification de #{filename.ljust(20)} ... "
  
  if File.exist?(filename)
    content = File.read(filename)
    
    # Vérifier le contenu si nécessaire
    if config[:content_check]
      missing_content = config[:content_check].select { |keyword| !content.include?(keyword) }
      
      if missing_content.empty?
        puts "✅ OK"
      else
        puts "⚠️  CONTENU INCOMPLET"
        puts "   Manque : #{missing_content.join(', ')}"
        invalid_files << filename
        all_ok = false
      end
    else
      puts "✅ OK"
    end
  else
    if config[:required]
      puts "❌ MANQUANT (REQUIS)"
      missing_files << filename
      all_ok = false
    else
      puts "⚠️  Manquant (optionnel)"
    end
  end
  
  if config[:description]
    puts "   → #{config[:description]}"
  end
end

puts ""
puts "=" * 80
puts "📊 RÉSUMÉ"
puts "=" * 80

if all_ok
  puts "✅ TOUS LES FICHIERS SONT PRÊTS !"
  puts ""
  puts "💡 PROCHAINES ÉTAPES :"
  puts ""
  puts "1. Commit les fichiers :"
  puts "   git add Aptfile .buildpacks .node-version .profile app.json"
  puts "   git commit -m '🚀 Fix: Ajout dépendances système pour production'"
  puts ""
  puts "2. Push sur GitHub :"
  puts "   git push origin main"
  puts ""
  puts "3. Déploie sur Easypanel :"
  puts "   → Clique sur le bouton 'Deploy'"
  puts ""
  puts "🔥 LE BUILD DEVRAIT RÉUSSIR À 100% !"
else
  puts "❌ PROBLÈMES DÉTECTÉS"
  puts ""
  
  if missing_files.any?
    puts "📁 Fichiers manquants (REQUIS) :"
    missing_files.each do |f|
      puts "   ❌ #{f}"
    end
    puts ""
  end
  
  if invalid_files.any?
    puts "⚠️  Fichiers avec contenu incomplet :"
    invalid_files.each do |f|
      puts "   ⚠️  #{f}"
    end
    puts ""
  end
  
  puts "💡 SOLUTION :"
  puts ""
  puts "Les fichiers manquants ont été créés par le script précédent."
  puts "Si tu vois ce message, c'est probablement parce que tu n'es pas"
  puts "dans le bon répertoire ou que les fichiers n'ont pas été créés."
  puts ""
  puts "Relance le script de création des fichiers de déploiement."
end

puts ""
puts "=" * 80

exit(all_ok ? 0 : 1)
