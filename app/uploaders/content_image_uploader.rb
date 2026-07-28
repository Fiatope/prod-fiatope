class ContentImageUploader < ImageUploader
  version :medium do
    process resize_to_limit: [720, 0]
    process :flatten
    process quality: 70
    process convert: :jpg
  end

  # To remove transparency from PNG
  def flatten
    manipulate! do |img|
      if defined?(Magick)
        # RMagick (production)
        img_list = Magick::ImageList.new
        img_list.from_blob img.to_blob
        img_list.new_image(img_list.first.columns, img_list.first.rows) { |options| options.background_color = "white" }
        img = img_list.reverse.flatten_images
      else
        # MiniMagick (development)
        ext = File.extname(img.respond_to?(:path) ? img.path.to_s : "").downcase
        if ext =~ /\.(png|gif|tiff?)$/
          img.combine_options do |c|
            c.background "white"
            c.alpha "remove"
          end
        end
      end
      img
    end
  end
end
