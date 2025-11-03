class AddNumeroIfuAndNumeroRccmToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :numero_ifu, :string
    add_column :projects, :numero_rccm, :string
  end
end
