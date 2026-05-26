class AddRegistrationNumberToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :registration_number, :string unless column_exists?(:organizations, :registration_number)
  end
end
