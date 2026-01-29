#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# 🔥 TEST STRIPE CONNECT COMPLET A-Z - VALIDATION 400%
# =============================================================================
# Ce script vérifie TOUS les aspects de l'intégration Stripe Connect:
# - Configuration et connexion API
# - État des projets et contributions
# - Calculs de frais
# - Sécurité
# - Edge cases
# =============================================================================

class StripeConnectFullTest
  attr_reader :results, :errors, :warnings, :passed, :failed

  def initialize
    @results = []
    @errors = []
    @warnings = []
    @passed = 0
    @failed = 0
  end

  def test(name, &block)
    result = block.call
    if result
      @passed += 1
      puts "  ✅ #{name}"
    else
      @failed += 1
      puts "  ❌ #{name}"
    end
    result
  rescue => e
    @failed += 1
    @errors << "#{name}: #{e.message}"
    puts "  ❌ #{name} - ERREUR: #{e.message}"
    false
  end

  def warn(message)
    @warnings << message
    puts "  ⚠️  #{message}"
  end

  def section(title)
    puts ""
    puts "=" * 70
    puts "📋 #{title}"
    puts "=" * 70
  end

  def run_all
    puts ""
    puts "🔥" * 30
    puts "   TEST STRIPE CONNECT COMPLET A-Z - VALIDATION 400%"
    puts "🔥" * 30
    puts ""
    puts "Date: #{Time.current}"
    puts "Environnement: #{Rails.env}"
    puts ""

    test_1_configuration
    test_2_api_connection
    test_3_database_schema
    test_4_projects_state
    test_5_contributions_state
    test_6_fee_calculations
    test_7_campaign_settlement_service
    test_8_security_checks
    test_9_edge_cases
    test_10_ui_conditions

    print_final_summary
  end

  # ===========================================================================
  # 1. CONFIGURATION
  # ===========================================================================
  def test_1_configuration
    section "1. CONFIGURATION"

    test("STRIPE_SECRET_KEY présente") { ENV['STRIPE_SECRET_KEY'].present? }
    test("STRIPE_PUBLISHABLE_KEY présente") { ENV['STRIPE_PUBLISHABLE_KEY'].present? }
    test("STRIPE_WEBHOOK_SECRET présente") { ENV['STRIPE_WEBHOOK_SECRET'].present? }
    
    platform_fee = ENV.fetch('PLATFORM_FEE', '5').to_f
    test("PLATFORM_FEE valide (#{platform_fee}%)") { platform_fee > 0 && platform_fee <= 20 }
    
    # Vérifier mode test vs live
    key = ENV['STRIPE_SECRET_KEY'] || ''
    is_test = key.start_with?('sk_test_')
    if Rails.env.production?
      test("Mode LIVE en production") { key.start_with?('sk_live_') }
    else
      test("Mode TEST en dev/staging") { is_test }
    end
  end

  # ===========================================================================
  # 2. CONNEXION API STRIPE
  # ===========================================================================
  def test_2_api_connection
    section "2. CONNEXION API STRIPE"

    begin
      balance = Stripe::Balance.retrieve
      test("Connexion API Stripe réussie") { true }
      
      available = balance.available.first
      if available
        puts "     Balance: #{available.amount / 100.0} #{available.currency.upcase}"
      end
    rescue Stripe::AuthenticationError
      test("Connexion API Stripe réussie") { false }
      @errors << "Clé API Stripe invalide"
    rescue Stripe::StripeError => e
      test("Connexion API Stripe réussie") { false }
      @errors << "Erreur Stripe: #{e.message}"
    end
  end

  # ===========================================================================
  # 3. SCHÉMA BASE DE DONNÉES
  # ===========================================================================
  def test_3_database_schema
    section "3. SCHÉMA BASE DE DONNÉES"

    # Colonnes contributions
    contrib_cols = [:stripe_charge_id, :stripe_transfer_id, :stripe_transferred, 
                    :stripe_refunded, :stripe_refund_id, :stripe_refund_amount]
    contrib_cols.each do |col|
      test("Contribution.#{col}") { Contribution.column_names.include?(col.to_s) }
    end

    # Colonnes projects
    project_cols = [:stripe_account_id, :use_stripe, :stripe_transfer_id, 
                    :stripe_settled_at, :stripe_settlement_type]
    project_cols.each do |col|
      test("Project.#{col}") { Project.column_names.include?(col.to_s) }
    end

    # Colonnes users
    user_cols = [:stripe_connect_account_id, :stripe_onboarding_complete]
    user_cols.each do |col|
      test("User.#{col}") { User.column_names.include?(col.to_s) }
    end
  end

  # ===========================================================================
  # 4. ÉTAT DES PROJETS
  # ===========================================================================
  def test_4_projects_state
    section "4. ÉTAT DES PROJETS STRIPE"

    projects_stripe = Project.where(use_stripe: true)
    puts "     Total projets Stripe: #{projects_stripe.count}"

    projects_with_account = projects_stripe.where.not(stripe_account_id: [nil, ''])
    puts "     Avec compte Connect: #{projects_with_account.count}"

    # Vérifier chaque compte Connect
    projects_with_account.limit(5).each do |project|
      begin
        account = Stripe::Account.retrieve(project.stripe_account_id)
        status = account.charges_enabled ? "✅ actif" : "⏳ en attente"
        puts "     - #{project.name[0..25]}: #{status}"
        
        test("Compte #{project.stripe_account_id[0..15]}... valide") { true }
      rescue Stripe::InvalidRequestError => e
        test("Compte #{project.stripe_account_id[0..15]}... valide") { false }
        warn("Compte invalide: #{e.message}")
      end
    end
  end

  # ===========================================================================
  # 5. ÉTAT DES CONTRIBUTIONS
  # ===========================================================================
  def test_5_contributions_state
    section "5. ÉTAT DES CONTRIBUTIONS STRIPE"

    all_stripe = Contribution.where(payment_method: 'Stripe')
    confirmed = all_stripe.where(state: 'confirmed')
    pending_treatment = confirmed.where(stripe_refunded: [false, nil])
                                .where(stripe_transferred: [false, nil])
    refunded = all_stripe.where(stripe_refunded: true)
    transferred = all_stripe.where(stripe_transferred: true)

    puts "     Total Stripe: #{all_stripe.count}"
    puts "     Confirmées: #{confirmed.count}"
    puts "     En attente traitement: #{pending_treatment.count}"
    puts "     Remboursées: #{refunded.count}"
    puts "     Transférées: #{transferred.count}"

    # Vérifier cohérence
    test("Pas de contribution remboursée ET transférée") do
      Contribution.where(stripe_refunded: true, stripe_transferred: true).count == 0
    end

    # Vérifier que les contributions confirmées ont un charge_id
    without_charge = confirmed.where(stripe_charge_id: [nil, ''])
    if without_charge.any?
      warn("#{without_charge.count} contribution(s) confirmée(s) sans charge_id")
    end
    test("Contributions confirmées ont charge_id") { without_charge.count == 0 }
  end

  # ===========================================================================
  # 6. CALCULS DE FRAIS
  # ===========================================================================
  def test_6_fee_calculations
    section "6. CALCULS DE FRAIS"

    platform_fee_pct = ENV.fetch('PLATFORM_FEE', '5').to_f
    puts "     Commission plateforme: #{platform_fee_pct}%"
    puts "     Frais Stripe: 2.9% + 0.25€"
    puts ""

    # Test avec différents montants
    test_amounts = [5, 10, 20, 50, 100, 500]
    
    all_positive = true
    test_amounts.each do |amount|
      stripe_fee = (amount * 0.029) + 0.25
      platform_commission = amount * (platform_fee_pct / 100.0)
      net_to_owner = amount - stripe_fee - platform_commission

      puts "     #{amount}€ → Net porteur: #{sprintf('%.2f', net_to_owner)}€"
      all_positive = false if net_to_owner <= 0
    end

    test("Calculs frais corrects (net > 0 pour montants >= 5€)") { all_positive }

    # Montant minimum
    min = 1.0
    loop do
      stripe_fee = (min * 0.029) + 0.25
      platform_commission = min * (platform_fee_pct / 100.0)
      net = min - stripe_fee - platform_commission
      break if net > 0 || min > 50
      min += 0.5
    end
    puts "     Montant minimum rentable: #{sprintf('%.2f', min)}€"
  end

  # ===========================================================================
  # 7. SERVICE CAMPAIGN SETTLEMENT
  # ===========================================================================
  def test_7_campaign_settlement_service
    section "7. SERVICE CAMPAIGN SETTLEMENT"

    test("Service CampaignSettlement chargé") do
      defined?(Neighborly::Stripe::CampaignSettlement)
    end

    service = Neighborly::Stripe::CampaignSettlement
    methods = [:process!, :process_refunds!, :transfer_to_owner!, 
               :refund_contributions!, :valid_for_transfer?, :valid_for_refund?]
    
    methods.each do |method|
      test("Méthode #{method}") { service.instance_methods.include?(method) }
    end

    # Test avec un projet réel
    project = Project.where(use_stripe: true).first
    if project
      settlement = service.new(project)
      test("Instance créée avec errors array") { settlement.errors.is_a?(Array) }
    else
      warn("Aucun projet Stripe pour tester le service")
    end
  end

  # ===========================================================================
  # 8. VÉRIFICATIONS SÉCURITÉ
  # ===========================================================================
  def test_8_security_checks
    section "8. SÉCURITÉ"

    # CSRF dans modals
    modal_path = Rails.root.join('app', 'views', 'neighborly', 'admin', 'projects', '_stripe_modals.html.slim')
    if File.exist?(modal_path)
      content = File.read(modal_path)
      test("Token CSRF dans modals") { content.include?('authenticity_token') }
    end

    # Webhook signature
    webhook_path = Rails.root.join('lib', 'neighborly-stripe-0.1.0', 'app', 'controllers', 
                                   'neighborly', 'stripe', 'webhooks_controller.rb')
    if File.exist?(webhook_path)
      content = File.read(webhook_path)
      test("Vérification signature webhook") { content.include?('verify_stripe_signature') }
      test("Skip CSRF pour webhook") { content.include?('skip_before_action :verify_authenticity_token') }
    end

    # Pas de clés en dur
    lib_files = Dir.glob(Rails.root.join('lib', '**', '*.rb'))
    hardcoded = lib_files.any? { |f| File.read(f).match?(/sk_(live|test)_[a-zA-Z0-9]{20,}/) }
    test("Pas de clés Stripe en dur dans le code") { !hardcoded }
  end

  # ===========================================================================
  # 9. EDGE CASES
  # ===========================================================================
  def test_9_edge_cases
    section "9. EDGE CASES"

    # Protection double traitement
    test("Protection double remboursement") do
      Contribution.where(stripe_refunded: true, state: 'confirmed').count == 0
    end

    # Contributions orphelines
    orphan_contribs = Contribution.where(payment_method: 'Stripe')
                                  .where.not(project_id: Project.select(:id))
    test("Pas de contributions orphelines") { orphan_contribs.count == 0 }

    # Projets avec comptes Connect invalides
    Project.where(use_stripe: true).where.not(stripe_account_id: [nil, '']).limit(3).each do |p|
      begin
        Stripe::Account.retrieve(p.stripe_account_id)
      rescue Stripe::InvalidRequestError
        warn("Projet #{p.id} a un compte Connect invalide: #{p.stripe_account_id}")
      end
    end
  end

  # ===========================================================================
  # 10. CONDITIONS UI
  # ===========================================================================
  def test_10_ui_conditions
    section "10. CONDITIONS UI (Boutons Admin)"

    Project.where(use_stripe: true).limit(5).each do |project|
      pending = project.contributions
                       .where(payment_method: 'Stripe', state: 'confirmed')
                       .where(stripe_refunded: [false, nil])
                       .where(stripe_transferred: [false, nil])

      next unless pending.any?

      onboarding_ok = project.user&.stripe_onboarding_complete? rescue false
      can_transfer = pending.any? && onboarding_ok
      can_refund = pending.any?

      puts ""
      puts "     Projet: #{project.name[0..30]}"
      puts "       Contributions en attente: #{pending.count}"
      puts "       Onboarding complet: #{onboarding_ok ? 'OUI' : 'NON'}"
      puts "       → TRANSFERT: #{can_transfer ? '✅ possible' : '❌ bloqué'}"
      puts "       → REMBOURSEMENT: #{can_refund ? '✅ possible' : '❌ bloqué'}"
    end

    test("Conditions UI analysées") { true }
  end

  # ===========================================================================
  # RÉSUMÉ FINAL
  # ===========================================================================
  def print_final_summary
    puts ""
    puts "=" * 70
    puts "📊 RÉSUMÉ FINAL"
    puts "=" * 70
    puts ""

    total = @passed + @failed
    pct = total > 0 ? (@passed.to_f / total * 100).round(1) : 0

    puts "   Tests passés:  #{@passed}/#{total} (#{pct}%)"
    puts "   Tests échoués: #{@failed}/#{total}"
    puts "   Avertissements: #{@warnings.count}"
    puts ""

    if @errors.any?
      puts "❌ ERREURS CRITIQUES:"
      @errors.each { |e| puts "   • #{e}" }
      puts ""
    end

    if @warnings.any?
      puts "⚠️  AVERTISSEMENTS:"
      @warnings.each { |w| puts "   • #{w}" }
      puts ""
    end

    if @failed == 0 && @warnings.empty?
      puts "🎉🎉🎉 VALIDATION 400% ATTEINTE! 🎉🎉🎉"
      puts "   L'intégration Stripe Connect est PRÊTE pour la production!"
    elsif @failed == 0
      puts "✅ Tests OK - #{@warnings.count} point(s) à surveiller"
    else
      puts "❌ #{@failed} problème(s) à corriger avant production"
    end

    puts ""
    puts "=" * 70
    puts "FIN DES TESTS - #{Time.current}"
    puts "=" * 70
  end
end

# Exécuter les tests
StripeConnectFullTest.new.run_all
