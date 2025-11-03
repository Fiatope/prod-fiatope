class CreateVendorOauthTokensAndOrangeMoneyTransactions < ActiveRecord::Migration
  def change
    create_table :vendor_oauth_tokens do |t|
      t.string :provider_name, index: true, null: false
      t.text :access_token, null: false
      t.datetime :expires_at, index: true, null: false
      t.string :token_type, null: false
      t.timestamps
    end

    create_table :orange_money_transactions do |t|
      t.integer :contribution_id, index: true
      t.string :order_id_string, uniq: true
      t.string :reference
      t.string :lang
      t.text :pay_token
      t.string :status_string
      t.text :payment_url
      t.text :notif_token
      t.string :txnid
    end
  end
end
