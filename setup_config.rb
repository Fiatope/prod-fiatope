#!/usr/bin/env ruby
require 'securerandom'

puts "🚀 CONFIGURATION DU PROJET PROD-FIATOPE..."
puts "=" * 60

# 1. Créer database.yml
puts "\n1️⃣ Création de config/database.yml..."

database_yml_content = <<~YAML
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    timeout: 5000
    host: 127.0.0.1
    username: postgres
    password: djouko

  development:
    <<: *default
    database: prod_fiatope_development

  test:
    <<: *default
    database: prod_fiatope_test

  production:
    <<: *default
    url: <%= ENV.fetch("DATABASE_URL", "") %>
YAML

File.write('config/database.yml', database_yml_content)
puts "   ✅ database.yml créé !"

# 2. Créer .env à partir de .env.example
puts "\n2️⃣ Création de .env..."

if File.exist?('.env')
  puts "   ℹ️  .env existe déjà, pas de modification"
else
  # Copier .env.example vers .env
  env_example = File.read('.env.example')
  
  # Remplir les valeurs essentielles
  env_content = env_example.gsub(/^(\w+)=\s*$/) do |line|
    key = $1
    case key
    when 'COMPANY_NAME'
      "#{key}=Fiatope"
    when 'CURRENCY'
      "#{key}=EUR"
    when 'TIMEZONE'
      "#{key}=Europe/Paris"
    when 'HOST'
      "#{key}=localhost:3001"
    when 'BASE_URL'
      "#{key}=http://localhost:3001"
    when 'BASE_DOMAIN'
      "#{key}=localhost"
    when 'PORT'
      "#{key}=3001"
    when 'EMAIL_CONTACT'
      "#{key}=contact@fiatope.com"
    when 'EMAIL_NO_REPLY'
      "#{key}=noreply@fiatope.com"
    when 'EMAIL_PAYMENTS'
      "#{key}=payments@fiatope.com"
    when 'EMAIL_PROJECTS'
      "#{key}=projects@fiatope.com"
    when 'EMAIL_SYSTEM'
      "#{key}=system@fiatope.com"
    when 'ADMIN_EMAIL'
      "#{key}=admin@fiatope.com"
    when 'ADMIN_PASSWORD'
      "#{key}=admin123"
    when 'SECRET_KEY_BASE'
      "#{key}=#{SecureRandom.hex(64)}"
    when 'SECRET_TOKEN'
      "#{key}=#{SecureRandom.hex(64)}"
    when 'DEVISE_SECRET_KEY'
      "#{key}=#{SecureRandom.hex(64)}"
    when 'PLATFORM_FEE'
      "#{key}=5.0"
    when 'PLATFORM_FEE_PERCENTAGE'
      "#{key}=5"
    when 'PLATFORM_FIX_FEE'
      "#{key}=0.5"
    when 'REDIS_PROVIDER'
      "#{key}=redis://localhost:6379"
    when 'MANGOPAY_PREPRODUCTION'
      "#{key}=true"
    else
      line
    end
  end
  
  File.write('.env', env_content)
  puts "   ✅ .env créé avec valeurs par défaut !"
end

puts "\n" + "=" * 60
puts "✅ CONFIGURATION TERMINÉE !"
puts "=" * 60
puts "\n📋 FICHIERS CRÉÉS :"
puts "   • config/database.yml"
puts "   • .env"
puts "\n🔑 CONFIGURATION BASE DE DONNÉES :"
puts "   Host     : 127.0.0.1"
puts "   User     : postgres"
puts "   Password : djouko"
puts "   DB Dev   : prod_fiatope_development"
puts "   DB Test  : prod_fiatope_test"
puts "\n📝 PROCHAINES ÉTAPES :"
puts "   1. bundle install"
puts "   2. rails db:create"
puts "   3. rails db:migrate"
puts "   4. rails db:seed"
puts "   5. rails server -p 3001"
puts ""
