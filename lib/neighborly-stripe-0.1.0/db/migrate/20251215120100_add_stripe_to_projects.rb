class AddStripeToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :stripe_account_id, :string
    add_column :projects, :use_stripe, :boolean, default: true
    
    add_index :projects, :stripe_account_id
    
    # Activer Stripe pour TOUS les projets existants automatiquement
    reversible do |dir|
      dir.up do
        execute "UPDATE projects SET use_stripe = true WHERE use_stripe IS NULL OR use_stripe = false"
      end
    end
  end
end
