class AddRegistrationNumberToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :registration_number, :string unless column_exists?(:organizations, :registration_number)
  end
end
