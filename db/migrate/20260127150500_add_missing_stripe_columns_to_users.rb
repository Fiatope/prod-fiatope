class AddMissingStripeColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :stripe_account_type, :string unless column_exists?(:users, :stripe_account_type)
    add_column :users, :stripe_charges_enabled, :boolean, default: false unless column_exists?(:users, :stripe_charges_enabled)
    add_column :users, :stripe_payouts_enabled, :boolean, default: false unless column_exists?(:users, :stripe_payouts_enabled)
  end
end
