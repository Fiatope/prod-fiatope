class AddAboutHtmlToPartners < ActiveRecord::Migration[6.1]
  def change
    add_column :partners, :about_html, :text
  end
end
