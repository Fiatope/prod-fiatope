class CreateNeighborlyAdminBanners < ActiveRecord::Migration[6.1]
  def change
    create_table :neighborly_admin_banners do |t|
      t.string :type
      t.string :name
      t.string :attachment

      t.timestamps
    end
  end
end
