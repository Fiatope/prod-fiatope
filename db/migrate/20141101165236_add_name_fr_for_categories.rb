class AddNameFrForCategories < ActiveRecord::Migration
  def change
    add_column :categories, :name_fr, :string

    Category.all.each do |category|
      category.name_fr = category.name_en
      category.save
    end
  end
end
