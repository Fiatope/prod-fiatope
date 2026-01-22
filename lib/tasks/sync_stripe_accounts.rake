namespace :stripe do
  desc "Synchroniser stripe_account_id de tous les projets depuis le compte du porteur"
  task sync_all_projects: :environment do
    puts "Synchronisation des comptes Stripe..."
    count = 0
    
    Project.includes(:user).find_each do |project|
      if project.stripe_account_id.blank? && project.user.stripe_connect_account_id.present?
        project.update_columns(
          stripe_account_id: project.user.stripe_connect_account_id,
          use_stripe: true
        )
        count += 1
        puts "  Projet #{project.id}: #{project.name} -> #{project.user.stripe_connect_account_id}"
      end
    end
    
    puts "#{count} projet(s) synchronisé(s)"
  end
end
