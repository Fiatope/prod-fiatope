class AddAdminValidationToContributions < ActiveRecord::Migration[6.1]
  def change
    add_column :contributions, :admin_validated, :boolean, default: false
    add_column :contributions, :admin_validated_at, :datetime
    add_column :contributions, :admin_validated_by, :integer
    add_index :contributions, :admin_validated
  end
end
