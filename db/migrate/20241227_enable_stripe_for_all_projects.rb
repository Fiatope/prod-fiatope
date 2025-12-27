class EnableStripeForAllProjects < ActiveRecord::Migration[6.1]
  def up
    # Activer Stripe pour tous les projets existants
    execute <<-SQL
      UPDATE projects SET use_stripe = true WHERE use_stripe IS NULL OR use_stripe = false;
    SQL
    
    # Changer la valeur par défaut pour les futurs projets
    change_column_default :projects, :use_stripe, from: false, to: true
  end
  
  def down
    # Revenir à l'état précédent si nécessaire
    change_column_default :projects, :use_stripe, from: true, to: false
  end
end
