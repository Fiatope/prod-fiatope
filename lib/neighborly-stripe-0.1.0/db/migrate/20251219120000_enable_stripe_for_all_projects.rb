class EnableStripeForAllProjects < ActiveRecord::Migration[6.1]
  def up
    # Activer Stripe pour TOUS les projets existants
    execute "UPDATE projects SET use_stripe = true WHERE use_stripe IS NULL OR use_stripe = false"
    puts "==> Stripe activé pour tous les projets existants"
  end

  def down
    # Ne rien faire - on ne veut pas désactiver Stripe
  end
end
