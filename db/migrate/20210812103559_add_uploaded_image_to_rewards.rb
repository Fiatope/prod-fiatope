class AddUploadedImageToRewards < ActiveRecord::Migration[6.1]
  def change
    add_column :rewards, :uploaded_image, :string
  end
end
