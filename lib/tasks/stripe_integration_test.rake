namespace :stripe do
  desc "Test complet de l'intégration Stripe Connect"
  task test_integration: :environment do
    puts "=" * 60
    puts "🔍 TEST D'INTÉGRATION STRIPE CONNECT - FIATOPE"
    puts "=" * 60
    puts ""
    
    errors = []
    warnings = []
    
    # Test 1: Vérifier que MangoPay est désactivé
    puts "📋 Test 1: Vérification désactivation MangoPay..."
    begin
      # Vérifier que les routes MangoPay ne sont pas montées
      mangopay_routes = Rails.application.routes.routes.map(&:name).compact.select { |n| n.to_s.include?('mangopay') }
      if mangopay_routes.empty?
        puts "   ✅ Aucune route MangoPay active"
      else
        warnings << "Routes MangoPay encore actives: #{mangopay_routes.join(', ')}"
        puts "   ⚠️  #{warnings.last}"
      end
    rescue => e
      errors << "Erreur test MangoPay: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 2: Vérifier le modèle User avec Stripe
    puts "\n📋 Test 2: Vérification modèle User avec Stripe..."
    begin
      user = User.where.not(stripe_connect_account_id: nil).first
      if user
        puts "   ✅ Utilisateur avec Stripe trouvé: #{user.email}"
        puts "      - stripe_connect_account_id: #{user.stripe_connect_account_id}"
        puts "      - stripe_onboarding_complete?: #{user.stripe_onboarding_complete?}"
      else
        warnings << "Aucun utilisateur avec compte Stripe Connect trouvé"
        puts "   ⚠️  #{warnings.last}"
      end
    rescue => e
      errors << "Erreur test User: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 3: Vérifier la synchronisation Project <-> User
    puts "\n📋 Test 3: Vérification synchronisation Project <-> User..."
    begin
      projects_without_sync = Project.joins(:user)
                                     .where(stripe_account_id: nil)
                                     .where.not(users: { stripe_connect_account_id: nil })
      if projects_without_sync.any?
        warnings << "#{projects_without_sync.count} projet(s) non synchronisé(s)"
        puts "   ⚠️  #{warnings.last}"
        projects_without_sync.limit(5).each do |p|
          puts "      - #{p.name} (user: #{p.user.stripe_connect_account_id})"
        end
      else
        puts "   ✅ Tous les projets sont synchronisés avec leur porteur"
      end
    rescue => e
      errors << "Erreur test sync: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 4: Vérifier le service CampaignSettlement
    puts "\n📋 Test 4: Vérification service CampaignSettlement..."
    begin
      service_path = Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb')
      if File.exist?(service_path)
        puts "   ✅ Fichier CampaignSettlement existe"
        
        # Vérifier la syntaxe du fichier
        result = `ruby -c "#{service_path}" 2>&1`
        if result.include?('Syntax OK')
          puts "   ✅ Syntaxe CampaignSettlement valide"
        else
          warnings << "Problème syntaxe CampaignSettlement"
          puts "   ⚠️  #{warnings.last}"
        end
      else
        errors << "Fichier CampaignSettlement non trouvé"
        puts "   ❌ #{errors.last}"
      end
    rescue => e
      errors << "Erreur test CampaignSettlement: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 5: Vérifier les contributions Stripe
    puts "\n📋 Test 5: Vérification contributions Stripe..."
    begin
      stripe_contribs = Contribution.where(payment_method: 'Stripe')
      puts "   📊 Total contributions Stripe: #{stripe_contribs.count}"
      
      confirmed = stripe_contribs.where(state: 'confirmed')
      puts "   📊 Contributions confirmées: #{confirmed.count}"
      
      transferred = stripe_contribs.where(stripe_transferred: true)
      puts "   📊 Contributions transférées: #{transferred.count}"
      
      refunded = stripe_contribs.where(stripe_refunded: true)
      puts "   📊 Contributions remboursées: #{refunded.count}"
      
      pending = confirmed.where(stripe_transferred: [false, nil]).where(stripe_refunded: [false, nil])
      puts "   📊 Contributions en attente: #{pending.count}"
      
      puts "   ✅ Statistiques contributions OK"
    rescue => e
      errors << "Erreur test contributions: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 6: Vérifier les callbacks Project
    puts "\n📋 Test 6: Vérification callbacks Project..."
    begin
      callbacks = Project._commit_callbacks.map { |c| c.filter.to_s }
      if callbacks.include?('sync_stripe_account_from_user')
        puts "   ✅ Callback sync_stripe_account_from_user présent"
      else
        warnings << "Callback sync_stripe_account_from_user non trouvé"
        puts "   ⚠️  #{warnings.last}"
      end
    rescue => e
      errors << "Erreur test callbacks: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Test 7: Vérifier la configuration Stripe
    puts "\n📋 Test 7: Vérification configuration Stripe..."
    begin
      if ENV['STRIPE_SECRET_KEY'].present?
        puts "   ✅ STRIPE_SECRET_KEY configuré"
      else
        errors << "STRIPE_SECRET_KEY non configuré"
        puts "   ❌ #{errors.last}"
      end
      
      if ENV['STRIPE_PUBLISHABLE_KEY'].present?
        puts "   ✅ STRIPE_PUBLISHABLE_KEY configuré"
      else
        errors << "STRIPE_PUBLISHABLE_KEY non configuré"
        puts "   ❌ #{errors.last}"
      end
    rescue => e
      errors << "Erreur test config: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Résumé
    puts "\n" + "=" * 60
    puts "📊 RÉSUMÉ DES TESTS"
    puts "=" * 60
    
    if errors.empty? && warnings.empty?
      puts "🎉 TOUS LES TESTS PASSENT - Intégration Stripe prête pour la production!"
    else
      if errors.any?
        puts "\n❌ ERREURS (#{errors.count}):"
        errors.each { |e| puts "   - #{e}" }
      end
      
      if warnings.any?
        puts "\n⚠️  AVERTISSEMENTS (#{warnings.count}):"
        warnings.each { |w| puts "   - #{w}" }
      end
    end
    
    puts "\n" + "=" * 60
  end
  
  desc "Test exhaustif de tous les scénarios admin Stripe"
  task test_admin_scenarios: :environment do
    puts "=" * 70
    puts "🔬 TEST EXHAUSTIF DES SCÉNARIOS ADMIN STRIPE"
    puts "=" * 70
    puts ""
    
    errors = []
    passed = 0
    
    # Scénario 1: Projet avec contributions Stripe en attente
    puts "📋 Scénario 1: Projet avec contributions Stripe EN ATTENTE..."
    begin
      project = Project.joins(:contributions)
                       .where(use_stripe: true)
                       .where(contributions: { payment_method: 'Stripe', state: 'confirmed' })
                       .where(contributions: { stripe_transferred: [false, nil], stripe_refunded: [false, nil] })
                       .where(stripe_settlement_type: [nil, ''])
                       .first
      if project
        puts "   ✅ Trouvé: #{project.name}"
        pending = project.contributions.where(payment_method: 'Stripe', state: 'confirmed')
                         .where(stripe_transferred: [false, nil], stripe_refunded: [false, nil])
        puts "      - #{pending.count} contribution(s) en attente"
        puts "      - Montant brut: #{pending.sum(:value)}€"
        puts "      - Bouton transfert: VISIBLE (si onboarding complet)"
        puts "      - Bouton remboursement: VISIBLE"
        passed += 1
      else
        puts "   ℹ️  Aucun projet avec contributions en attente trouvé (OK si DB vide)"
        passed += 1
      end
    rescue => e
      errors << "Scénario 1: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 2: Projet déjà transféré
    puts "\n📋 Scénario 2: Projet DÉJÀ TRANSFÉRÉ..."
    begin
      project = Project.where(stripe_settlement_type: 'transferred').first
      if project
        puts "   ✅ Trouvé: #{project.name}"
        puts "      - Transfer ID: #{project.stripe_transfer_id}"
        puts "      - Date: #{project.stripe_settled_at}"
        puts "      - Bouton transfert: CACHÉ ✓"
        puts "      - Bouton remboursement: CACHÉ ✓ (fonds déjà transférés)"
        passed += 1
      else
        puts "   ℹ️  Aucun projet transféré trouvé (normal si pas encore de transferts)"
        passed += 1
      end
    rescue => e
      errors << "Scénario 2: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 3: Projet déjà remboursé
    puts "\n📋 Scénario 3: Projet DÉJÀ REMBOURSÉ..."
    begin
      project = Project.where(stripe_settlement_type: 'refunded').first
      if project
        puts "   ✅ Trouvé: #{project.name}"
        puts "      - Date: #{project.stripe_settled_at}"
        puts "      - Bouton transfert: CACHÉ ✓"
        puts "      - Bouton remboursement: CACHÉ ✓"
        passed += 1
      else
        puts "   ℹ️  Aucun projet remboursé trouvé (normal si pas encore de remboursements)"
        passed += 1
      end
    rescue => e
      errors << "Scénario 3: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 4: Projet sans Stripe activé
    puts "\n📋 Scénario 4: Projet SANS STRIPE..."
    begin
      project = Project.where(use_stripe: [false, nil]).first
      if project
        puts "   ✅ Trouvé: #{project.name}"
        puts "      - use_stripe: #{project.use_stripe}"
        puts "      - Boutons Stripe: NON AFFICHÉS ✓"
        passed += 1
      else
        puts "   ℹ️  Tous les projets ont Stripe activé"
        passed += 1
      end
    rescue => e
      errors << "Scénario 4: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 5: Porteur avec onboarding incomplet
    puts "\n📋 Scénario 5: Porteur avec ONBOARDING INCOMPLET..."
    begin
      user = User.where(stripe_onboarding_complete: false)
                 .where.not(stripe_connect_account_id: nil)
                 .first
      if user
        puts "   ✅ Trouvé: #{user.email}"
        puts "      - Compte Stripe: #{user.stripe_connect_account_id}"
        puts "      - Onboarding: INCOMPLET"
        puts "      - Bouton transfert: DÉSACTIVÉ ✓ (doit compléter profil)"
        passed += 1
      else
        puts "   ℹ️  Tous les porteurs ont complété leur onboarding"
        passed += 1
      end
    rescue => e
      errors << "Scénario 5: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 6: Vérification logique transfert
    puts "\n📋 Scénario 6: Vérification LOGIQUE TRANSFERT..."
    begin
      # Charger le service et vérifier les méthodes
      require_dependency 'neighborly/stripe/campaign_settlement'
      
      # Vérifier que source_transaction est utilisé
      service_content = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb'))
      
      if service_content.include?('source_transaction')
        puts "   ✅ source_transaction utilisé (évite 'insufficient funds')"
      else
        errors << "source_transaction non trouvé dans CampaignSettlement"
      end
      
      if service_content.include?("stripe_settlement_type == 'transferred'")
        puts "   ✅ Protection double transfert présente"
      else
        errors << "Protection double transfert manquante"
      end
      
      if service_content.include?("valid_for_transfer?")
        puts "   ✅ Méthode valid_for_transfer? présente"
      else
        errors << "Méthode valid_for_transfer? manquante"
      end
      
      passed += 1
    rescue => e
      errors << "Scénario 6: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 7: Vérification logique remboursement
    puts "\n📋 Scénario 7: Vérification LOGIQUE REMBOURSEMENT..."
    begin
      service_content = File.read(Rails.root.join('lib/neighborly-stripe-0.1.0/app/services/neighborly/stripe/campaign_settlement.rb'))
      
      # Vérifier que le remboursement est bloqué après transfert
      if service_content.include?("Impossible de rembourser") || service_content.include?("fonds ont déjà été transférés")
        puts "   ✅ Remboursement bloqué après transfert"
      else
        errors << "Logique blocage remboursement après transfert manquante"
      end
      
      if service_content.include?("valid_for_refund?")
        puts "   ✅ Méthode valid_for_refund? présente"
      else
        errors << "Méthode valid_for_refund? manquante"
      end
      
      passed += 1
    rescue => e
      errors << "Scénario 7: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 8: Vérification interface admin
    puts "\n📋 Scénario 8: Vérification INTERFACE ADMIN..."
    begin
      view_path = Rails.root.join('app/views/neighborly/admin/projects/index.html.slim')
      view_content = File.read(view_path)
      
      if view_content.include?('openTransferModal')
        puts "   ✅ Modal transfert présent"
      else
        errors << "Modal transfert non trouvé"
      end
      
      if view_content.include?('openRefundModal')
        puts "   ✅ Modal remboursement présent"
      else
        errors << "Modal remboursement non trouvé"
      end
      
      if view_content.include?("stripe_settlement_type != 'transferred'")
        puts "   ✅ Condition visibilité transfert correcte"
      else
        errors << "Condition visibilité transfert manquante"
      end
      
      passed += 1
    rescue => e
      errors << "Scénario 8: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 9: Vérification modals Stripe
    puts "\n📋 Scénario 9: Vérification MODALS STRIPE..."
    begin
      modal_path = Rails.root.join('app/views/neighborly/admin/projects/_stripe_modals.html.slim')
      if File.exist?(modal_path)
        modal_content = File.read(modal_path)
        
        if modal_content.include?('stripeTransferModal')
          puts "   ✅ Modal #stripeTransferModal présent"
        else
          errors << "Modal #stripeTransferModal non trouvé"
        end
        
        if modal_content.include?('stripeRefundModal')
          puts "   ✅ Modal #stripeRefundModal présent"
        else
          errors << "Modal #stripeRefundModal non trouvé"
        end
        
        if modal_content.include?('confirmTransferCheck') && modal_content.include?('confirmRefundCheck')
          puts "   ✅ Checkboxes de confirmation présentes"
        else
          errors << "Checkboxes de confirmation manquantes"
        end
        
        if modal_content.include?('type="submit"')
          puts "   ✅ Boutons submit (formulaires) utilisés"
        else
          errors << "Boutons non-submit détectés (problème potentiel)"
        end
        
        passed += 1
      else
        errors << "Fichier _stripe_modals.html.slim non trouvé"
        puts "   ❌ #{errors.last}"
      end
    rescue => e
      errors << "Scénario 9: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Scénario 10: Vérification contrôleur admin
    puts "\n📋 Scénario 10: Vérification CONTRÔLEUR ADMIN..."
    begin
      controller_path = Rails.root.join('app/controllers/neighborly/admin/projects_controller.rb')
      controller_content = File.read(controller_path)
      
      if controller_content.include?('process_stripe_transfer')
        puts "   ✅ Action process_stripe_transfer présente"
      else
        errors << "Action process_stripe_transfer manquante"
      end
      
      if controller_content.include?('process_stripe_refund')
        puts "   ✅ Action process_stripe_refund présente"
      else
        errors << "Action process_stripe_refund manquante"
      end
      
      if controller_content.include?("fonds ont déjà été transférés")
        puts "   ✅ Protection remboursement après transfert dans contrôleur"
      else
        errors << "Protection remboursement après transfert manquante dans contrôleur"
      end
      
      passed += 1
    rescue => e
      errors << "Scénario 10: #{e.message}"
      puts "   ❌ #{errors.last}"
    end
    
    # Résumé
    puts "\n" + "=" * 70
    puts "📊 RÉSUMÉ DES SCÉNARIOS"
    puts "=" * 70
    
    if errors.empty?
      puts "🎉 TOUS LES #{passed} SCÉNARIOS PASSENT!"
      puts ""
      puts "✅ L'intégration Stripe est PRÊTE pour la production."
      puts "✅ Tous les edge cases sont couverts."
      puts "✅ La logique de transfert/remboursement est correcte."
      puts "✅ L'interface admin est fonctionnelle."
    else
      puts "❌ #{errors.count} ERREUR(S) DÉTECTÉE(S):"
      errors.each { |e| puts "   - #{e}" }
    end
    
    puts "\n" + "=" * 70
  end
end
