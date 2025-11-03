class AddNullRewardContribution < ActiveRecord::Migration[6.1]
  def change
    change_column :contributions, :reward_id, :integer, null: true

  end
end
