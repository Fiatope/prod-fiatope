class AddStripePayoutTrackingToProjectsAndContributions < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :stripe_transfer_created_at, :datetime unless column_exists?(:projects, :stripe_transfer_created_at)
    add_column :projects, :stripe_payout_id, :string unless column_exists?(:projects, :stripe_payout_id)
    add_column :projects, :stripe_payout_ids, :text unless column_exists?(:projects, :stripe_payout_ids)
    add_column :projects, :stripe_payout_status, :string unless column_exists?(:projects, :stripe_payout_status)
    add_column :projects, :stripe_payout_source, :string unless column_exists?(:projects, :stripe_payout_source)
    add_column :projects, :stripe_payout_amount_cents, :integer unless column_exists?(:projects, :stripe_payout_amount_cents)
    add_column :projects, :stripe_payout_currency, :string unless column_exists?(:projects, :stripe_payout_currency)
    add_column :projects, :stripe_payout_arrival_date, :datetime unless column_exists?(:projects, :stripe_payout_arrival_date)
    add_column :projects, :stripe_payout_paid_at, :datetime unless column_exists?(:projects, :stripe_payout_paid_at)
    add_column :projects, :stripe_payout_failed_at, :datetime unless column_exists?(:projects, :stripe_payout_failed_at)
    add_column :projects, :stripe_payout_failure_code, :string unless column_exists?(:projects, :stripe_payout_failure_code)
    add_column :projects, :stripe_payout_failure_message, :text unless column_exists?(:projects, :stripe_payout_failure_message)

    add_column :contributions, :stripe_transfer_amount_cents, :integer unless column_exists?(:contributions, :stripe_transfer_amount_cents)
    add_column :contributions, :stripe_transfer_currency, :string unless column_exists?(:contributions, :stripe_transfer_currency)

    add_index :projects, :stripe_payout_id unless index_exists?(:projects, :stripe_payout_id)
    add_index :projects, :stripe_payout_status unless index_exists?(:projects, :stripe_payout_status)
    add_index :projects, :stripe_transfer_created_at unless index_exists?(:projects, :stripe_transfer_created_at)
  end
end
