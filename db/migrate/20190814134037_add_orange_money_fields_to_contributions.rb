class AddOrangeMoneyFieldsToContributions < ActiveRecord::Migration
  def change
    change_table :contributions do |t|
      t.string :response_code
      t.string :transaction_number
      t.string :response_message
    end
  end
end
