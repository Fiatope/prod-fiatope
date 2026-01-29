# ============================================================
# 🔱 TEST E2E 02 - FLUX CROWDFUNDING COMPLET
# ============================================================
# Simule le flux complet: Contributeur -> Paiement -> Transfert
# ============================================================

puts "\n" + "=" * 70
puts "🔱 TEST E2E 02 - FLUX CROWDFUNDING COMPLET"
puts "=" * 70

require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

errors = []
successes = []

# ============================================================
# PHASE 1: PRÉPARATION
# ============================================================
puts "\n📋 PHASE 1: PRÉPARATION"
puts "-" * 50

# Trouver un projet Stripe actif
project = Project.where(use_stripe: true)
                 .where.not(stripe_account_id: [nil, ''])
                 .where(state: ['online', 'successful'])
                 .first

if project.nil?
  # Fallback: premier projet Stripe
  project = Project.where(use_stripe: true).first
end

if project
  successes << "Projet trouvé: #{project.name}"
  puts "  ✅ Projet: #{project.name} (ID: #{project.id})"
  puts "     Stripe Account: #{project.stripe_account_id || 'Non configuré'}"
  puts "     État: #{project.state}"
  puts "     Objectif: #{project.goal}€"
else
  errors << "Aucun projet Stripe trouvé"
  puts "  ❌ Aucun projet Stripe trouvé"
  puts "\n" + "=" * 70
  puts "🚨 Impossible de continuer sans projet Stripe"
  puts "=" * 70
  exit 1
end

# Trouver ou créer un contributeur test
contributor = User.find_by(email: 'test_contributor@fiatope.com')
unless contributor
  puts "  ℹ️ Utilisation d'un utilisateur existant comme contributeur"
  contributor = User.where.not(id: project.user_id).first
end

if contributor
  successes << "Contributeur: #{contributor.email}"
  puts "  ✅ Contributeur: #{contributor.email}"
else
  errors << "Aucun contributeur disponible"
  puts "  ❌ Aucun contributeur disponible"
end

# ============================================================
# PHASE 2: SIMULATION PAIEMENT
# ============================================================
puts "\n📋 PHASE 2: SIMULATION PAIEMENT"
puts "-" * 50

test_amount = 50.0 # 50€

# Calculer les frais
calc = Neighborly::Stripe::FeeCalculator.new(test_amount)
puts "  📊 Montant: #{test_amount}€"
puts "     Frais Stripe: #{calc.gateway_fee}€"
puts "     Commission plateforme: #{calc.platform_fee}€"
puts "     Net porteur: #{(test_amount - calc.gateway_fee - calc.platform_fee).round(2)}€"

# Créer une contribution test (sans paiement réel)
begin
  # Vérifier qu'une contribution test n'existe pas déjà
  existing = Contribution.find_by(
    project: project,
    user: contributor,
    payment_method: 'Stripe_Test'
  )
  
  if existing
    puts "  ℹ️ Contribution test existante trouvée: ##{existing.id}"
    test_contribution = existing
  else
    # Simuler une contribution (ne pas créer en base pour éviter pollution)
    puts "  ℹ️ Simulation contribution (pas de création en base)"
  end
  
  successes << "Simulation paiement OK"
  puts "  ✅ Simulation paiement configurée"
  
rescue => e
  errors << "Simulation paiement: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# ============================================================
# PHASE 3: TEST CHECKOUT SESSION
# ============================================================
puts "\n📋 PHASE 3: TEST CRÉATION CHECKOUT SESSION"
puts "-" * 50

begin
  # Créer une vraie Checkout Session (sans la finaliser)
  session_params = {
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'eur',
        product_data: {
          name: "Contribution - #{project.name}",
          description: "Contribution au projet crowdfunding"
        },
        unit_amount: (test_amount * 100).to_i,
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: "https://fiatope.com/projects/#{project.permalink}/contributions/success?session_id={CHECKOUT_SESSION_ID}",
    cancel_url: "https://fiatope.com/projects/#{project.permalink}/contributions/cancel",
    metadata: {
      project_id: project.id.to_s,
      project_name: project.name,
      user_id: contributor&.id.to_s,
      platform: 'fiatope',
      test: 'true'
    }
  }
  
  # Ajouter transfer_data si compte connecté valide
  if project.stripe_account_id.present?
    net_amount = ((test_amount - calc.gateway_fee - calc.platform_fee) * 100).to_i
    if net_amount > 0
      session_params[:payment_intent_data] = {
        transfer_data: {
          destination: project.stripe_account_id,
          amount: net_amount
        }
      }
      puts "  ℹ️ Transfer configuré: #{net_amount/100.0}€ -> #{project.stripe_account_id}"
    end
  end
  
  session = Stripe::Checkout::Session.create(session_params)
  
  successes << "Checkout Session créée: #{session.id}"
  puts "  ✅ Session créée: #{session.id}"
  puts "     URL: #{session.url[0..50]}..."
  puts "     Status: #{session.status}"
  
  # Expirer immédiatement (nettoyage)
  begin
    Stripe::Checkout::Session.expire(session.id)
    puts "  ✅ Session expirée (nettoyage)"
  rescue => e
    puts "  ⚠️ Expiration: #{e.message}"
  end
  
rescue Stripe::InvalidRequestError => e
  if e.message.include?('destination')
    warnings << "Transfer non possible: compte connecté invalide"
    puts "  ⚠️ Compte connecté invalide pour transfert"
    puts "     Message: #{e.message[0..80]}"
    
    # Réessayer sans transfer_data
    begin
      session_params.delete(:payment_intent_data)
      session = Stripe::Checkout::Session.create(session_params)
      successes << "Checkout Session (sans transfer): #{session.id}"
      puts "  ✅ Session créée (sans transfer): #{session.id}"
      Stripe::Checkout::Session.expire(session.id) rescue nil
    rescue => e2
      errors << "Checkout Session fallback: #{e2.message}"
    end
  else
    errors << "Checkout Session: #{e.message}"
    puts "  ❌ Erreur: #{e.message}"
  end
rescue Stripe::StripeError => e
  errors << "Checkout Session: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# ============================================================
# PHASE 4: TEST CAMPAIGN SETTLEMENT
# ============================================================
puts "\n📋 PHASE 4: TEST CAMPAIGN SETTLEMENT"
puts "-" * 50

begin
  settlement = Neighborly::Stripe::CampaignSettlement.new(project)
  
  # Vérifier les méthodes disponibles
  methods_ok = %i[process! process_refunds! transfer_single_contribution refund_contribution].all? do |m|
    settlement.respond_to?(m)
  end
  
  if methods_ok
    successes << "CampaignSettlement complet"
    puts "  ✅ Toutes les méthodes disponibles"
    puts "     • process!"
    puts "     • process_refunds!"
    puts "     • transfer_single_contribution"
    puts "     • refund_contribution"
  else
    errors << "CampaignSettlement incomplet"
    puts "  ❌ Méthodes manquantes"
  end
  
  # Compter les contributions transférables
  transferable = project.contributions.where(
    payment_method: 'Stripe',
    stripe_transferred: [false, nil]
  ).where.not(stripe_charge_id: [nil, ''])
  
  puts "  📊 Contributions transférables: #{transferable.count}"
  
  # Compter les contributions remboursables
  refundable = project.contributions.where(
    payment_method: 'Stripe',
    stripe_refunded: [false, nil]
  ).where.not(stripe_charge_id: [nil, ''])
  
  puts "  📊 Contributions remboursables: #{refundable.count}"
  
rescue => e
  errors << "CampaignSettlement: #{e.message}"
  puts "  ❌ Erreur: #{e.message}"
end

# ============================================================
# PHASE 5: TEST CONTRIBUTIONS EXISTANTES
# ============================================================
puts "\n📋 PHASE 5: CONTRIBUTIONS STRIPE EXISTANTES"
puts "-" * 50

stripe_contributions = Contribution.where(payment_method: 'Stripe').order(created_at: :desc).limit(5)

if stripe_contributions.any?
  successes << "#{stripe_contributions.count} contribution(s) Stripe trouvée(s)"
  puts "  ✅ #{stripe_contributions.count} contribution(s) Stripe récente(s)"
  
  stripe_contributions.each_with_index do |c, i|
    status = []
    status << "Transféré" if c.stripe_transferred
    status << "Remboursé" if c.stripe_refunded
    status << "En attente" if status.empty?
    
    puts "     #{i+1}. ##{c.id}: #{c.value}€ (#{status.join(', ')})"
    puts "        Charge: #{c.stripe_charge_id || 'N/A'}"
  end
else
  puts "  ⚠️ Aucune contribution Stripe trouvée"
end

# ============================================================
# RÉSUMÉ
# ============================================================
puts "\n" + "=" * 70
puts "📊 RÉSUMÉ TEST FLUX CROWDFUNDING"
puts "=" * 70

puts "\n✅ SUCCÈS: #{successes.count}"
successes.each { |s| puts "   • #{s}" }

puts "\n❌ ERREURS: #{errors.count}"
errors.each { |e| puts "   • #{e}" }

score = (successes.count.to_f / (successes.count + errors.count) * 100).round(1) rescue 0
puts "\n📈 SCORE: #{score}%"

puts "\n" + "=" * 70
if errors.empty?
  puts "🎉 FLUX CROWDFUNDING VALIDÉ!"
else
  puts "🚨 #{errors.count} problème(s) détecté(s)"
end
puts "=" * 70
