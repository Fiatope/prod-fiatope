namespace :stripe do
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
