class ContentImageUploader < ImageUploader
  version :medium do
    process resize_to_limit: [720, 0]
    process :flatten
    process quality: 70
    process convert: :jpg
  end

  # To remove transparency from PNG (MiniMagick — replaces old RMagick code)
  def flatten
    manipulate! do |img|
      img.combine_options do |c|
        c.background "white"
        c.alpha "remove"
      end
      img
    end
  end
end
