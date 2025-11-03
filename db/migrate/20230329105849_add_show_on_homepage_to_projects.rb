class AddShowOnHomepageToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :show_on_homepage, :boolean, :default => false
  end
end
