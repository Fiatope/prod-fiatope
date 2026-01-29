# frozen_string_literal: true

namespace :stripe do
  desc "Vérifier et corriger les contributions remboursées sur Stripe mais non marquées en DB"
  task fix_refunded: :environment do
    puts "=" * 80
    puts "🔍 VÉRIFICATION DES CONTRIBUTIONS REMBOURSÉES"
    puts "=" * 80
    puts ""

    contributions = Contribution.where(payment_method: 'Stripe', state: 'confirmed')
                               .where(stripe_refunded: [false, nil])
                               .where.not(stripe_charge_id: [nil, ''])

    puts "📋 Contributions à vérifier: #{contributions.count}"
    puts ""

    fixed_count = 0
    errors = []

    contributions.each do |contribution|
      puts "-" * 60
      puts "Contribution ##{contribution.id}"
      puts "  Utilisateur: #{contribution.user&.name || 'N/A'}"
      puts "  Montant: #{contribution.value}€"
      puts "  Charge ID: #{contribution.stripe_charge_id}"
      
      begin
        charge = Stripe::Charge.retrieve(contribution.stripe_charge_id)
        
        puts "  État Stripe: refunded=#{charge.refunded}, amount_refunded=#{charge.amount_refunded / 100.0}€"
        
        if charge.refunded || charge.amount_refunded > 0
          puts "  ⚠️  INCOHÉRENCE: Remboursé sur Stripe mais pas en DB!"
          
          refunds = Stripe::Refund.list(charge: contribution.stripe_charge_id, limit: 1)
          refund = refunds.data.first
          
          if refund
            contribution.update!(
              stripe_refunded: true,
              stripe_refund_id: refund.id,
              stripe_refund_amount: refund.amount / 100.0
            )
            contribution.update_column(:state, 'refunded')
            
            puts "  ✅ CORRIGÉ!"
            fixed_count += 1
          end
        else
          puts "  ✅ OK: Non remboursé"
        end
        
      rescue => e
        puts "  ❌ Erreur: #{e.message}"
        errors << "Contribution #{contribution.id}: #{e.message}"
      end
    end

    puts ""
    puts "=" * 80
    puts "📊 RÉSUMÉ: #{fixed_count} corrigées, #{errors.count} erreurs"
    puts "=" * 80
  end

  desc "Lister les contributions Stripe en attente de traitement"
  task list_pending: :environment do
    puts "=" * 80
    puts "📋 CONTRIBUTIONS STRIPE EN ATTENTE"
    puts "=" * 80
    
    pending = Contribution.where(payment_method: 'Stripe', state: 'confirmed')
                         .where(stripe_refunded: [false, nil])
                         .where(stripe_transferred: [false, nil])
    
    puts "Total: #{pending.count}"
    puts ""
    
    pending.each do |c|
      puts "  ##{c.id}: #{c.user&.name || 'Anonyme'} - #{c.value}€ - Projet: #{c.project&.name&.[](0..30)}"
    end
  end
end
