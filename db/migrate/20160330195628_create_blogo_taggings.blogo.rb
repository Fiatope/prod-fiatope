# This migration comes from blogo (originally 20140218134620)
class CreateBlogoTaggings < ActiveRecord::Migration
  def change
    taggings_table = "#{Blogo.table_name_prefix}taggings"

    create_table(taggings_table) do |t|
      t.integer :blogo_post_id, null: false
      t.integer :tag_id , null: false
    end

    add_index taggings_table, [:tag_id, :blogo_post_id], unique: true

    if defined?(Foreigner)
      tags_table  = "#{Blogo.table_name_prefix}tags"
      posts_table = "#{Blogo.table_name_prefix}posts"

      add_foreign_key taggings_table, tags_table , column: :tag_id
      add_foreign_key taggings_table, posts_table, column: :blogo_post_id
    end
  end
end
