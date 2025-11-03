class CreateArticles < ActiveRecord::Migration[6.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.text :description
      t.string :uploaded_image
      t.references :reward, foreign_key: true

      t.timestamps
    end
  end
end
