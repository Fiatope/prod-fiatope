class CreatePartners < ActiveRecord::Migration
  def up
    # This is not nice but necessary because the migration creating
    # the partner table has been migrated from another project and needs
    # to be dropped before creating the correct one.
    if ActiveRecord::Base.connection.table_exists? 'partners'
      drop_table :partners
    end

    create_table :partners do |t|
      t.string :name, null: false
      t.string :headline, null: false
      t.string :permalink, null: false
      t.text :about
      t.string :uploaded_image
      t.string :hero_image
      t.string :primary_theme_color
    end

    change_table :projects do |t|
      t.integer :partner_id, index: true
    end

    change_table :users do |t|
      t.integer :partner_id, index: true
    end
  end

  def down
    remove_column :users, :partner_id
    remove_column :projects, :partner_id

    if ActiveRecord::Base.connection.table_exists? 'partners'
      drop_table :partners
    end
  end
end
