class AddMangopayRequiredFieldToUsers < ActiveRecord::Migration
  def change
    add_column :users, :birthday, :date
    add_column :users, :nationality, :string
    add_column :users, :residence_country, :string
  end
end
