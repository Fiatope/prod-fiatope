class AddStripeToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :stripe_account_id, :string
    add_column :projects, :use_stripe, :boolean, default: false
    
    add_index :projects, :stripe_account_id
  end
end
