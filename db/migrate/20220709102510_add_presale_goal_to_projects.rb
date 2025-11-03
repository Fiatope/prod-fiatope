class AddPresaleGoalToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :presale_goal, :integer
  end
end
