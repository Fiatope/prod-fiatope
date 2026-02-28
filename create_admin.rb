require_relative 'config/environment'

puts "🔧 Création du compte ADMIN pour PROD-FIATOPE..."

# Supprimer l'ancien si existe
old_admin = User.find_by(email: 'admin@fiatope.com')
if old_admin
  puts "   Suppression de l'ancien compte admin..."
  old_admin.destroy
end

# Créer le nouveau
admin = User.new(
  email: 'admin@fiatope.com',
  password: 'admin123',
  password_confirmation: 'admin123',
  name: 'Admin Fiatope',
  admin: true,
  birthday: Date.new(1990, 1, 1),
  nationality: 'FR',
  residence_country: 'FR'
)

admin.skip_confirmation!
admin.save(validate: false)

puts ""
puts "=" * 50
puts "✅ COMPTE ADMIN CRÉÉ AVEC SUCCÈS !"
puts "=" * 50
puts ""
puts "🔑 IDENTIFIANTS :"
puts "   Email    : admin@fiatope.com"
puts "   Password : admin123"
puts ""
puts "🌐 POUR TE CONNECTER :"
puts "   1. Va sur : http://localhost:3001/users/sign_in"
puts "   2. Saisis les identifiants ci-dessus"
puts "   3. Puis va sur : http://localhost:3001/admin"
puts ""
puts "✅ Tu auras accès complet à l'interface admin !"
puts ""
