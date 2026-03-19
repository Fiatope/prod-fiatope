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
      begin
        img.combine_options do |c|
          c.background "white"
          c.alpha "remove"
        end
      rescue => e
        Rails.logger.warn "[ContentImageUploader] flatten failed: #{e.message}"
      end
      img
    end
  end
end
