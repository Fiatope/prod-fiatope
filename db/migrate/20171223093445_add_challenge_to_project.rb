class AddChallengeToProject < ActiveRecord::Migration
  def change
    add_column :projects, :challenge,  :integer

  end
end

