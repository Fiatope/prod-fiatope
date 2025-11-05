#!/usr/bin/env ruby
require 'pg'

puts "=" * 80
puts "🗄️  CRÉATION MANUELLE DES BASES DE DONNÉES"
puts "=" * 80
puts ""

# Configuration
DB_CONFIG = {
  host: '127.0.0.1',
  port: 5432,
  user: 'postgres',
  password: 'djouko'
}

databases = ['prod_fiatope_development', 'prod_fiatope_test']

puts "📍 Connexion à PostgreSQL..."
begin
  # Connexion à la base postgres par défaut
  conn = PG.connect(DB_CONFIG.merge(dbname: 'postgres'))
  puts "✅ Connexion réussie !"
  puts ""
  
  databases.each do |db_name|
    puts "📍 Vérification de #{db_name}..."
    
    # Vérifier si la base existe
    result = conn.exec("SELECT 1 FROM pg_database WHERE datname='#{db_name}'")
    
    if result.ntuples > 0
      puts "   ⚠️  Base #{db_name} existe déjà"
    else
      puts "   Création de #{db_name}..."
      conn.exec("CREATE DATABASE #{db_name}")
      puts "   ✅ Base #{db_name} créée !"
    end
    puts ""
  end
  
  conn.close
  
  puts "=" * 80
  puts "✅ TOUTES LES BASES SONT PRÊTES !"
  puts "=" * 80
  puts ""
  puts "Bases disponibles :"
  databases.each { |db| puts "  • #{db}" }
  puts ""
  
rescue PG::Error => e
  puts "❌ ERREUR PostgreSQL:"
  puts "   #{e.message}"
  puts ""
  puts "Vérifiez que:"
  puts "  1. PostgreSQL est démarré"
  puts "  2. Le mot de passe 'djouko' est correct"
  puts "  3. L'utilisateur 'postgres' existe"
  exit 1
end
