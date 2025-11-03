class AddTableContributionRewards < ActiveRecord::Migration[6.1]
  def change
    create_table :contribution_rewards do |t|
      t.references :contribution, foreign_key: true
      t.references :reward, foreign_key: true
    end
  end
end
