class SyncExistingProjectsStripeAccounts < ActiveRecord::Migration[6.1]
  def up
    # Synchroniser le stripe_account_id de tous les projets existants
    # depuis le stripe_connect_account_id de leur porteur
    execute <<-SQL
      UPDATE projects
      SET stripe_account_id = users.stripe_connect_account_id,
          use_stripe = true
      FROM users
      WHERE projects.user_id = users.id
        AND projects.stripe_account_id IS NULL
        AND users.stripe_connect_account_id IS NOT NULL
        AND users.stripe_connect_account_id != ''
    SQL
    
    # Logger le nombre de projets mis à jour
    count = Project.where.not(stripe_account_id: nil).count
    say "#{count} projets avec stripe_account_id après migration"
  end
  
  def down
    # Pas de rollback - les données sont précieuses
  end
end
