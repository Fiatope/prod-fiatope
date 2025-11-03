class AddEnglishTextileFields < ActiveRecord::Migration
  def change
    add_column :projects, :english_textile, :text

  end
end
