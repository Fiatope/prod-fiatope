class HeroImageUploader < ImageUploader
  process convert: :jpg

  version :blur do
    process resize_to_limit: [2000, 0]
    process :apply_blur
    process quality: 70
  end

  def apply_blur
    manipulate! do |img|
      img.blur("0x5")
    end
  end

end
