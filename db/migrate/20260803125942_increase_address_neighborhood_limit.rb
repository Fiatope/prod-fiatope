class IncreaseAddressNeighborhoodLimit < ActiveRecord::Migration[6.1]
  def change
    change_column :projects, :address_neighborhood, :text
  end
end
