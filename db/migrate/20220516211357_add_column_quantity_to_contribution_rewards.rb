class AddColumnQuantityToContributionRewards < ActiveRecord::Migration[6.1]
  def change
    add_column :contribution_rewards, :quantity,  :integer
  end
end
