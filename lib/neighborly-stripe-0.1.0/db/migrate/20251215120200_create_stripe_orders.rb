class CreateStripeOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :stripe_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :contribution, foreign_key: true
      
      t.string :stripe_payment_intent_id
      t.string :stripe_checkout_session_id
      t.string :stripe_charge_id
      t.string :stripe_transfer_id
      
      t.integer :amount_cents, null: false
      t.string :currency, default: 'eur'
      t.integer :platform_fee_cents
      
      t.string :status
      t.text :metadata
      
      t.timestamps
    end
    
    add_index :stripe_orders, :stripe_payment_intent_id
    add_index :stripe_orders, :stripe_checkout_session_id
    add_index :stripe_orders, :status
  end
end
