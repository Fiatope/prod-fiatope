class CreatePayPlusAfricaTransactions < ActiveRecord::Migration
  def change
    create_table :pay_plus_africa_transactions do |t|
      t.integer :contribution_id, index: true
      t.string :order_id_string, uniq: true
      t.string :reference
      t.string :status_string
      t.string :invoice_number
      t.text :payment_url
      t.text :notif_token
    end
  end
end
