require_relative 'config/environment'

puts "Création du canal..."

admin = User.find_by(email: 'admin@fiatope.com')
admin.update_column(:phone_number, '+22900000001')

channel = Channel.create!(
  name: 'Général',
  permalink: 'general',
  description: 'Canal par défaut pour tous les projets',
  user: admin
)

puts "✅ Canal créé : #{channel.name} (ID: #{channel.id})"
