class CreateFollows < ActiveRecord::Migration
  def change
    create_table :follows do |t|
      t.string  :follower_type
      t.integer :followerid
      t.string  :followable_type
      t.integer :followableid
      t.datetime :created_at
    end

    add_index :follows, ["followerid", "follower_type"],     :name => "fk_follows"
    add_index :follows, ["followableid", "followable_type"], :name => "fk_followables"
  end
end
