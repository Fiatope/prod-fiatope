class AddColumnsToBankInformations < ActiveRecord::Migration[6.1]
  def change
    add_column :bank_informations, :us_account_number, :string
    add_column :bank_informations, :us_account_aba, :string
    add_column :bank_informations, :ca_account_type, :string
    add_column :bank_informations, :ca_institution_number, :string
    add_column :bank_informations, :ca_account_number, :string
    add_column :bank_informations, :ca_branch_code, :string
    add_column :bank_informations, :ca_bank_name, :string
    add_column :bank_informations, :fr_key, :string
    add_column :bank_informations, :us_key, :string
    add_column :bank_informations, :ca_key, :string
    add_column :bank_informations, :other_key, :string
    add_column :bank_informations, :other_account_number, :string
    add_column :bank_informations, :other_bic, :string
    add_column :bank_informations, :other_country, :string
    add_column :bank_informations, :owner_city, :string
    add_column :bank_informations, :owner_region, :string
    add_column :bank_informations, :owner_postal_code, :string
    add_column :bank_informations, :owner_address, :string
  end
end
