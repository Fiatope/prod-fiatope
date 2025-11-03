class AddEnglishToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :english, :text
    add_column :projects, :english_html, :text
  end
end
