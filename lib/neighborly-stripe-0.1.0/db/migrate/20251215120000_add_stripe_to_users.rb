class AddStripeToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :stripe_customer_id, :string
    add_column :users, :stripe_connect_account_id, :string
    add_column :users, :stripe_onboarding_complete, :boolean, default: false
    
    add_index :users, :stripe_customer_id
    add_index :users, :stripe_connect_account_id
  end
end
