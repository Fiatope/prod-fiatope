class CreateLikes < ActiveRecord::Migration
  def change
    create_table :likes do |t|
      t.string  :liker_type
      t.integer :likerid
      t.string  :likeable_type
      t.integer :likeableid
      t.datetime :created_at
    end

    add_index :likes, ["likerid", "liker_type"],       :name => "fk_likes"
    add_index :likes, ["likeableid", "likeable_type"], :name => "fk_likeables"
  end
end
