class AddMaximumArticlesToRewards < ActiveRecord::Migration[6.1]
  def change
    add_column :rewards, :maximum_articles, :integer
  end
end
