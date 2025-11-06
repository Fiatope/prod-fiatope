#!/usr/bin/env ruby
# Script de vérification complète de l'environnement

puts "=" * 80
puts "🔍 VÉRIFICATION COMPLÈTE DE L'ENVIRONNEMENT - PROD-FIATOPE"
puts "=" * 80
puts ""

# Couleurs pour Windows PowerShell
def green(text)
  "✅ #{text}"
end

def red(text)
  "❌ #{text}"
end

def yellow(text)
  "⚠️  #{text}"
end

def blue(text)
  "ℹ️  #{text}"
end

results = []

# 1. VERSION RUBY
puts "📍 1. VÉRIFICATION RUBY"
ruby_version = RUBY_VERSION
puts "   Version détectée: #{ruby_version}"
if ruby_version.start_with?('3.1')
  puts green("Ruby 3.1.x OK")
  results << {item: "Ruby", status: :ok, detail: ruby_version}
else
  puts red("Ruby 3.1.x requis")
  results << {item: "Ruby", status: :error, detail: ruby_version}
end
puts ""

# 2. BUNDLER
puts "📍 2. VÉRIFICATION BUNDLER"
begin
  bundler_version = `bundle -v`.strip
  puts "   #{bundler_version}"
  puts green("Bundler OK")
  results << {item: "Bundler", status: :ok, detail: bundler_version}
rescue
  puts red("Bundler non installé")
  results << {item: "Bundler", status: :error, detail: "Non installé"}
end
puts ""

# 3. POSTGRESQL
puts "📍 3. VÉRIFICATION POSTGRESQL"
begin
  pg_version = `psql --version`.strip
  puts "   #{pg_version}"
  if pg_version.include?("17") || pg_version.include?("16") || pg_version.include?("15")
    puts green("PostgreSQL OK")
    results << {item: "PostgreSQL", status: :ok, detail: pg_version}
  else
    puts yellow("PostgreSQL version ancienne")
    results << {item: "PostgreSQL", status: :warning, detail: pg_version}
  end
rescue
  puts red("PostgreSQL non trouvé")
  results << {item: "PostgreSQL", status: :error, detail: "Non trouvé"}
end
puts ""

# 4. REDIS
puts "📍 4. VÉRIFICATION REDIS"
begin
  redis_check = `redis-cli ping 2>&1`.strip
  if redis_check.include?("PONG")
    puts "   Redis répond: PONG"
    puts green("Redis OK")
    results << {item: "Redis", status: :ok, detail: "Actif"}
  else
    puts red("Redis ne répond pas")
    results << {item: "Redis", status: :error, detail: "Inactif"}
  end
rescue
  puts red("Redis non trouvé")
  results << {item: "Redis", status: :error, detail: "Non trouvé"}
end
puts ""

# 5. FICHIERS DE CONFIGURATION
puts "📍 5. VÉRIFICATION FICHIERS DE CONFIGURATION"

config_files = [
  {name: "config/database.yml", required: true},
  {name: ".env", required: true},
  {name: "Gemfile", required: true},
  {name: "Gemfile.lock", required: false},
  {name: "config/boot.rb", required: true},
  {name: "config/application.rb", required: true}
]

config_files.each do |file|
  if File.exist?(file[:name])
    puts green("#{file[:name]} existe")
    results << {item: file[:name], status: :ok, detail: "Présent"}
  else
    if file[:required]
      puts red("#{file[:name]} MANQUANT")
      results << {item: file[:name], status: :error, detail: "Manquant"}
    else
      puts yellow("#{file[:name]} absent")
      results << {item: file[:name], status: :warning, detail: "Absent"}
    end
  end
end
puts ""

# 6. GEMS INSTALLÉES
puts "📍 6. VÉRIFICATION GEMS"
if File.exist?("Gemfile.lock")
  gem_count = File.readlines("Gemfile.lock").grep(/^\s{4}\w/).count
  puts "   #{gem_count} gems détectées dans Gemfile.lock"
  puts green("Gems installées")
  results << {item: "Gems", status: :ok, detail: "#{gem_count} gems"}
else
  puts yellow("Gemfile.lock absent - bundle install nécessaire")
  results << {item: "Gems", status: :warning, detail: "À installer"}
end
puts ""

# 7. DATABASE.YML
puts "📍 7. VÉRIFICATION DATABASE.YML"
if File.exist?("config/database.yml")
  db_config = File.read("config/database.yml")
  if db_config.include?("prod_fiatope")
    puts green("database.yml configuré pour prod_fiatope")
    results << {item: "Database config", status: :ok, detail: "Configuré"}
  else
    puts yellow("database.yml existe mais nom DB à vérifier")
    results << {item: "Database config", status: :warning, detail: "À vérifier"}
  end
else
  puts red("config/database.yml MANQUANT")
  results << {item: "Database config", status: :error, detail: "Manquant"}
end
puts ""

# 8. .ENV
puts "📍 8. VÉRIFICATION .ENV"
if File.exist?(".env")
  env_content = File.read(".env")
  essential_vars = ['SECRET_KEY_BASE', 'DATABASE_URL', 'REDIS_URL', 'DEVISE_SECRET_KEY']
  missing_vars = essential_vars.reject { |var| env_content.include?(var) }
  
  if missing_vars.empty?
    puts green(".env contient toutes les variables essentielles")
    results << {item: ".env", status: :ok, detail: "Complet"}
  else
    puts yellow(".env existe mais variables manquantes: #{missing_vars.join(', ')}")
    results << {item: ".env", status: :warning, detail: "Variables manquantes"}
  end
else
  puts red(".env MANQUANT")
  results << {item: ".env", status: :error, detail: "Manquant"}
end
puts ""

# RÉSUMÉ FINAL
puts ""
puts "=" * 80
puts "📊 RÉSUMÉ DE LA VÉRIFICATION"
puts "=" * 80
puts ""

ok_count = results.count { |r| r[:status] == :ok }
warning_count = results.count { |r| r[:status] == :warning }
error_count = results.count { |r| r[:status] == :error }

puts "✅ OK       : #{ok_count}"
puts "⚠️  WARNINGS : #{warning_count}"
puts "❌ ERREURS  : #{error_count}"
puts ""

if error_count > 0
  puts red("⚠️  DES CORRECTIONS SONT NÉCESSAIRES")
  puts ""
  puts "Éléments en erreur:"
  results.select { |r| r[:status] == :error }.each do |r|
    puts "  ❌ #{r[:item]}: #{r[:detail]}"
  end
elsif warning_count > 0
  puts yellow("⚠️  ENVIRONNEMENT FONCTIONNEL MAIS AVEC WARNINGS")
else
  puts green("🎉 ENVIRONNEMENT PARFAIT ! PRÊT À LANCER !")
end

puts ""
puts "=" * 80
puts "Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts "=" * 80
