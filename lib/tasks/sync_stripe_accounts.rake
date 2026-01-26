namespace :stripe do
  desc "Test d'intégration complet Stripe Connect"
  task test_integration: :environment do
    puts "=" * 80
    puts "🧪 TEST D'INTÉGRATION STRIPE CONNECT - FIATOPE"
    puts "=" * 80
    puts ""
    
    results = { passed: 0, failed: 0, warnings: 0 }
    
    # === TEST 1: Configuration ===
    puts "📋 1. CONFIGURATION"
    puts "-" * 40
    
    if ENV['STRIPE_SECRET_KEY'].present?
      puts "  ✅ STRIPE_SECRET_KEY configurée"
      results[:passed] += 1
    else
      puts "  ❌ STRIPE_SECRET_KEY manquante!"
      results[:failed] += 1
    end
    
    if ENV['STRIPE_PUBLISHABLE_KEY'].present?
      puts "  ✅ STRIPE_PUBLISHABLE_KEY configurée"
      results[:passed] += 1
    else
      puts "  ❌ STRIPE_PUBLISHABLE_KEY manquante!"
      results[:failed] += 1
    end
    
    if ENV['STRIPE_WEBHOOK_SECRET'].present?
      puts "  ✅ STRIPE_WEBHOOK_SECRET configurée"
      results[:passed] += 1
    else
      puts "  ⚠️  STRIPE_WEBHOOK_SECRET manquante (webhooks non sécurisés)"
      results[:warnings] += 1
    end
    
    # === TEST 2: Connexion API Stripe ===
    puts ""
    puts "📋 2. CONNEXION API STRIPE"
    puts "-" * 40
    
    begin
      account = Stripe::Account.retrieve
      puts "  ✅ Connexion API OK - Compte: #{account.id}"
      puts "     Type: #{account.type}, Pays: #{account.country}"
      results[:passed] += 1
    rescue Stripe::AuthenticationError => e
      puts "  ❌ Erreur d'authentification: #{e.message}"
      results[:failed] += 1
    rescue => e
      puts "  ❌ Erreur API: #{e.message}"
      results[:failed] += 1
    end
    
    # === TEST 3: Synchronisation User-Projets ===
    puts ""
    puts "📋 3. SYNCHRONISATION USER-PROJETS"
    puts "-" * 40
    
    users_with_stripe = User.where.not(stripe_connect_account_id: [nil, ''])
    puts "  📊 Users avec compte Stripe: #{users_with_stripe.count}"
    
    sync_issues = 0
    users_with_stripe.each do |user|
      user.projects.each do |project|
        if project.stripe_account_id != user.stripe_connect_account_id
          sync_issues += 1
          puts "  ⚠️  Désync: #{project.name} (#{project.stripe_account_id || 'nil'}) != #{user.stripe_connect_account_id}"
        end
      end
    end
    
    if sync_issues == 0
      puts "  ✅ Tous les projets sont synchronisés"
      results[:passed] += 1
    else
      puts "  ❌ #{sync_issues} projet(s) non synchronisé(s)"
      results[:failed] += 1
    end
    
    # === TEST 4: Onboarding Status ===
    puts ""
    puts "📋 4. STATUT ONBOARDING"
    puts "-" * 40
    
    onboarding_complete = users_with_stripe.where(stripe_onboarding_complete: true).count
    onboarding_pending = users_with_stripe.where(stripe_onboarding_complete: [false, nil]).count
    
    puts "  📊 Onboarding complet: #{onboarding_complete}"
    puts "  📊 Onboarding en attente: #{onboarding_pending}"
    
    if onboarding_pending > 0
      puts "  ⚠️  #{onboarding_pending} user(s) doivent compléter l'onboarding"
      results[:warnings] += 1
    else
      results[:passed] += 1
    end
    
    # === TEST 5: Vérification comptes Stripe Connect (si possible) ===
    puts ""
    puts "📋 5. VÉRIFICATION COMPTES STRIPE"
    puts "-" * 40
    
    verified = 0
    invalid = 0
    users_with_stripe.limit(5).each do |user|
      begin
        stripe_account = Stripe::Account.retrieve(user.stripe_connect_account_id)
        status = []
        status << "charges" if stripe_account.charges_enabled
        status << "payouts" if stripe_account.payouts_enabled
        puts "  ✅ #{user.email}: #{status.join(', ') || 'restricted'}"
        verified += 1
        
        # Vérifier cohérence onboarding
        if stripe_account.charges_enabled && stripe_account.payouts_enabled && !user.stripe_onboarding_complete?
          puts "     ⚠️  Onboarding devrait être marqué comme complet!"
          user.update_column(:stripe_onboarding_complete, true)
        end
      rescue Stripe::InvalidRequestError => e
        puts "  ❌ #{user.email}: Compte invalide - #{e.message}"
        invalid += 1
      rescue => e
        puts "  ⚠️  #{user.email}: Erreur - #{e.message}"
      end
    end
    
    if invalid == 0
      results[:passed] += 1
    else
      results[:failed] += 1
    end
    
    # === TEST 6: Contributions Stripe ===
    puts ""
    puts "📋 6. CONTRIBUTIONS STRIPE"
    puts "-" * 40
    
    stripe_contributions = Contribution.where(payment_method: 'Stripe')
    confirmed = stripe_contributions.where(state: 'confirmed').count
    pending = stripe_contributions.where(state: 'pending').count
    transferred = stripe_contributions.where(stripe_transferred: true).count
    refunded = stripe_contributions.where(stripe_refunded: true).count
    
    puts "  📊 Total contributions Stripe: #{stripe_contributions.count}"
    puts "     - Confirmées: #{confirmed}"
    puts "     - En attente: #{pending}"
    puts "     - Transférées: #{transferred}"
    puts "     - Remboursées: #{refunded}"
    
    results[:passed] += 1
    
    # === TEST 7: Projets prêts pour transfert ===
    puts ""
    puts "📋 7. PROJETS PRÊTS POUR TRANSFERT"
    puts "-" * 40
    
    ready_projects = Project.joins(:user)
                           .where.not(stripe_account_id: [nil, ''])
                           .where(users: { stripe_onboarding_complete: true })
                           .where(stripe_settlement_type: [nil, ''])
    
    ready_projects.each do |p|
      contrib_count = p.contributions.where(payment_method: 'Stripe', state: 'confirmed', stripe_transferred: [false, nil]).count
      total = p.contributions.where(payment_method: 'Stripe', state: 'confirmed', stripe_transferred: [false, nil]).sum(:value)
      if contrib_count > 0
        puts "  💰 #{p.name}: #{contrib_count} contrib(s), #{total}€"
      end
    end
    
    puts "  ℹ️  #{ready_projects.count} projet(s) prêts pour transfert" if ready_projects.none? { |p| p.contributions.where(payment_method: 'Stripe', state: 'confirmed').any? }
    results[:passed] += 1
    
    # === RÉSUMÉ ===
    puts ""
    puts "=" * 80
    puts "📊 RÉSUMÉ DES TESTS"
    puts "=" * 80
    puts "  ✅ Réussis:      #{results[:passed]}"
    puts "  ⚠️  Avertissements: #{results[:warnings]}"
    puts "  ❌ Échoués:      #{results[:failed]}"
    puts ""
    
    if results[:failed] == 0
      puts "🎉 TOUS LES TESTS CRITIQUES SONT PASSÉS!"
    else
      puts "⚠️  #{results[:failed]} TEST(S) CRITIQUE(S) ÉCHOUÉ(S)"
      puts "   Veuillez corriger les problèmes ci-dessus avant la mise en production."
    end
    
    puts "=" * 80
  end

  desc "Synchronise les stripe_account_id de tous les projets avec leurs porteurs"
  task sync_all_projects: :environment do
    puts "=" * 60
    puts "🔄 SYNCHRONISATION DES COMPTES STRIPE"
    puts "=" * 60
    puts ""
    
    synced = 0
    already_synced = 0
    no_account = 0
    errors = 0
    
    Project.includes(:user).find_each do |project|
      user = project.user
      
      unless user
        puts "⚠️  Projet #{project.id} (#{project.name}) - Pas de porteur"
        errors += 1
        next
      end
      
      unless user.stripe_connect_account_id.present?
        no_account += 1
        next
      end
      
      if project.stripe_account_id == user.stripe_connect_account_id && project.use_stripe?
        already_synced += 1
        next
      end
      
      begin
        project.update_columns(
          stripe_account_id: user.stripe_connect_account_id,
          use_stripe: true
        )
        synced += 1
        puts "✅ #{project.name} -> #{user.stripe_connect_account_id}"
      rescue => e
        errors += 1
        puts "❌ #{project.name}: #{e.message}"
      end
    end
    
    puts ""
    puts "=" * 60
    puts "📊 RÉSULTAT"
    puts "=" * 60
    puts "✅ Synchronisés: #{synced}"
    puts "✓  Déjà OK:      #{already_synced}"
    puts "⏳ Sans compte:   #{no_account}"
    puts "❌ Erreurs:       #{errors}"
    puts ""
    
    if synced > 0
      puts "🎉 #{synced} projet(s) mis à jour avec succès!"
    else
      puts "ℹ️  Aucun projet à synchroniser."
    end
  end
  
  desc "Affiche l'état de synchronisation Stripe de tous les projets"
  task status: :environment do
    puts "=" * 80
    puts "📊 ÉTAT DE SYNCHRONISATION STRIPE"
    puts "=" * 80
    puts ""
    
    projects = Project.includes(:user).order(:created_at)
    
    ready = []
    pending_onboarding = []
    not_synced = []
    no_stripe = []
    
    projects.find_each do |project|
      user = project.user
      next unless user
      
      if project.use_stripe? && project.stripe_account_id.present?
        if user.stripe_onboarding_complete?
          ready << project
        else
          pending_onboarding << project
        end
      elsif user.stripe_connect_account_id.present? && project.stripe_account_id != user.stripe_connect_account_id
        not_synced << project
      else
        no_stripe << project
      end
    end
    
    puts "✅ PRÊTS (#{ready.count}):"
    ready.first(10).each { |p| puts "   - #{p.name} (#{p.user.email})" }
    puts "   ... et #{ready.count - 10} autres" if ready.count > 10
    
    puts ""
    puts "⏳ ONBOARDING EN COURS (#{pending_onboarding.count}):"
    pending_onboarding.each { |p| puts "   - #{p.name} (#{p.user.email})" }
    
    puts ""
    puts "🔗 À SYNCHRONISER (#{not_synced.count}):"
    not_synced.each { |p| puts "   - #{p.name} (#{p.user.email}) -> #{p.user.stripe_connect_account_id}" }
    
    puts ""
    puts "❌ SANS STRIPE (#{no_stripe.count}):"
    no_stripe.first(10).each { |p| puts "   - #{p.name} (#{p.user.email})" }
    puts "   ... et #{no_stripe.count - 10} autres" if no_stripe.count > 10
    
    puts ""
    puts "=" * 80
    puts "ACTIONS RECOMMANDÉES:"
    if not_synced.any?
      puts "  → Exécuter: rake stripe:sync_all_projects"
    end
    if pending_onboarding.any?
      puts "  → Contacter les porteurs pour compléter leur onboarding Stripe"
    end
    puts "=" * 80
  end
end
