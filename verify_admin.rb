require_relative 'config/environment'

puts "🔍 Vérification du compte admin..."
puts ""

admin = User.find_by(email: 'admin@fiatope.com')

if admin
  puts "✅ Compte admin trouvé !"
  puts ""
  puts "Informations:"
  puts "  Email: #{admin.email}"
  puts "  Name: #{admin.name}"
  puts "  Admin: #{admin.admin?}"
  puts "  ID: #{admin.id}"
  puts ""
  puts "🎉 Prêt à te connecter avec:"
  puts "  Email: admin@fiatope.com"
  puts "  Password: admin123"
else
  puts "❌ Aucun compte admin trouvé"
  puts "Lance: ruby create_admin.rb"
end
