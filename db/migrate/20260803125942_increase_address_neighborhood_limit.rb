class IncreaseAddressNeighborhoodLimit < ActiveRecord::Migration[6.1]
  def up
    # Sauvegarder la définition de la vue
    execute "DROP VIEW IF EXISTS projects_for_home"
    
    # Modifier la colonne
    change_column :projects, :address_neighborhood, :text
    
    # Recréer la vue
    execute <<-SQL
      CREATE OR REPLACE VIEW projects_for_home AS
      SELECT * FROM projects
      WHERE state IN ('online', 'waiting_funds', 'successful', 'failed')
      ORDER BY created_at DESC
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS projects_for_home"
    change_column :projects, :address_neighborhood, :string
    execute <<-SQL
      CREATE OR REPLACE VIEW projects_for_home AS
      SELECT * FROM projects
      WHERE state IN ('online', 'waiting_funds', 'successful', 'failed')
      ORDER BY created_at DESC
    SQL
  end
end
