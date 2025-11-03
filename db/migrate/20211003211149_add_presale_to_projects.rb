class AddPresaleToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :presale, :boolean, :default => false
  end
end
