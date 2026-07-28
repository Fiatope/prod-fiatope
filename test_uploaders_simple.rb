#!/usr/bin/env ruby
# Test simple de syntaxe des uploaders sans charger Rails

puts "=" * 80
puts "TEST SYNTAXE UPLOADERS - KWENDOO"
puts "=" * 80

errors = []

# Test 1: Vérifier que les fichiers peuvent être parsés
puts "\n1. Test de syntaxe Ruby"
puts "-" * 80

uploaders = Dir.glob('app/uploaders/*.rb')

uploaders.each do |file|
  begin
    # Vérifier la syntaxe sans exécuter
    result = `ruby -c "#{file}" 2>&1`
    if $?.success?
      puts "✓ #{File.basename(file)}"
    else
      puts "✗ #{File.basename(file)}: #{result}"
      errors << "#{file}: #{result}"
    end
  rescue => e
    puts "✗ #{File.basename(file)}: #{e.message}"
    errors << "#{file}: #{e.message}"
  end
end

# Test 2: Vérifier image_processing.rb
puts "\n2. Test module ImageProcessing"
puts "-" * 80

if File.exist?('app/uploaders/image_processing.rb')
  content = File.read('app/uploaders/image_processing.rb')
  
  checks = {
    'Module ImageProcessing défini' => content.include?('module KwendooImageProcessing') || content.include?('module FiatopeImageProcessing') || content.include?('module ImageProcessing'),
    'Méthode included définie' => content.include?('def self.included'),
    'CarrierWave::RMagick inclus' => content.include?('CarrierWave::RMagick'),
    'CarrierWave::MiniMagick inclus' => content.include?('CarrierWave::MiniMagick'),
    'Condition production' => content.include?('Rails.env.production?'),
    'Module RMagick quality' => content.include?('module CarrierWave') && content.include?('module RMagick'),
    'Module MiniMagick quality' => content.include?('module MiniMagick')
  }
  
  checks.each do |desc, result|
    puts result ? "✓ #{desc}" : "✗ #{desc}"
    errors << "image_processing.rb: #{desc} manquant" unless result
  end
else
  puts "✗ Fichier image_processing.rb non trouvé"
  errors << "image_processing.rb manquant"
end

# Test 3: Vérifier content_image_uploader.rb
puts "\n3. Test ContentImageUploader"
puts "-" * 80

if File.exist?('app/uploaders/content_image_uploader.rb')
  content = File.read('app/uploaders/content_image_uploader.rb')
  
  checks = {
    'Hérite de ImageUploader' => content.include?('< ImageUploader'),
    'Version :medium définie' => content.include?('version :medium'),
    'Méthode flatten définie' => content.include?('def flatten'),
    'Condition defined?(Magick)' => content.include?('defined?(Magick)'),
    'Branche RMagick' => content.include?('Magick::ImageList'),
    'Branche MiniMagick' => content.include?('combine_options')
  }
  
  checks.each do |desc, result|
    puts result ? "✓ #{desc}" : "✗ #{desc}"
    errors << "content_image_uploader.rb: #{desc} manquant" unless result
  end
else
  puts "✗ Fichier content_image_uploader.rb non trouvé"
  errors << "content_image_uploader.rb manquant"
end

# Test 4: Vérifier carrierwave.rb
puts "\n4. Test configuration CarrierWave"
puts "-" * 80

if File.exist?('config/initializers/carrierwave.rb')
  content = File.read('config/initializers/carrierwave.rb')
  
  checks = {
    'CarrierWave.configure présent' => content.include?('CarrierWave.configure'),
    'Storage :file en dev' => content.include?('config.storage = :file'),
    'Storage :fog en prod' => content.include?('config.storage = :fog'),
    'AWS credentials' => content.include?('fog_credentials'),
    'AWS_REGION' => content.include?("ENV['AWS_REGION']"),
    'AWS_BUCKET' => content.include?("ENV['AWS_BUCKET']"),
    'fog_public = true' => content.include?('fog_public') && content.include?('true')
  }
  
  checks.each do |desc, result|
    puts result ? "✓ #{desc}" : "✗ #{desc}"
    errors << "carrierwave.rb: #{desc} manquant" unless result
  end
else
  puts "✗ Fichier carrierwave.rb non trouvé"
  errors << "carrierwave.rb manquant"
end

# Test 5: Vérifier Gemfile
puts "\n5. Test Gemfile"
puts "-" * 80

if File.exist?('Gemfile')
  content = File.read('Gemfile')
  
  has_rmagick = content.match?(/gem\s+['"]rmagick['"]/)
  has_mini_magick = content.match?(/gem\s+['"]mini_magick['"]/)
  has_carrierwave = content.match?(/gem\s+['"]carrierwave['"]/)
  
  puts has_rmagick ? "✓ rmagick dans Gemfile" : "⚠ rmagick absent (sera installé en prod)"
  puts has_mini_magick ? "✓ mini_magick dans Gemfile" : "✗ mini_magick absent"
  puts has_carrierwave ? "✓ carrierwave dans Gemfile" : "✗ carrierwave absent"
  
  errors << "Gemfile: mini_magick manquant" unless has_mini_magick
  errors << "Gemfile: carrierwave manquant" unless has_carrierwave
else
  puts "✗ Gemfile non trouvé"
  errors << "Gemfile manquant"
end

# Résumé
puts "\n" + "=" * 80
if errors.empty?
  puts "✓ TOUS LES TESTS PASSÉS"
  puts "Les uploaders sont correctement configurés"
else
  puts "✗ #{errors.length} ERREUR(S) DÉTECTÉE(S):"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end
puts "=" * 80
