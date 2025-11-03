class AddCfaValueToContributions < ActiveRecord::Migration
  def up
    add_column :contributions, :cfa_value, :decimal
  end

  def down
    remove_column :contributions, :cfa_value
  end
end
