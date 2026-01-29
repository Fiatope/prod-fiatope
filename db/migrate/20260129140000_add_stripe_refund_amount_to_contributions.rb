class AddStripeRefundAmountToContributions < ActiveRecord::Migration[6.1]
  def change
    # Ajouter le montant réellement remboursé au contributeur
    # (après déduction des frais Stripe et commission plateforme)
    add_column :contributions, :stripe_refund_amount, :decimal, precision: 10, scale: 2 unless column_exists?(:contributions, :stripe_refund_amount)
  end
end
