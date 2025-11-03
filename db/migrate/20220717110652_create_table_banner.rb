class CreateTableBanner < ActiveRecord::Migration[6.1]
  def change
    create_table :banners do |t|
      t.string :type
      t.string :name
      t.string :attachment
      t.timestamps
    end
  end
end