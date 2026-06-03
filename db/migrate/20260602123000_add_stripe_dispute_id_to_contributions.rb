class AddStripeDisputeIdToContributions < ActiveRecord::Migration[6.1]
  def change
    add_column :contributions, :stripe_dispute_id, :string unless column_exists?(:contributions, :stripe_dispute_id)
    add_index :contributions, :stripe_dispute_id unless index_exists?(:contributions, :stripe_dispute_id)
  end
end
