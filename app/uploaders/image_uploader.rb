class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def extension_white_list
    %w(jpg jpeg gif png) unless mounted_as == :video_thumbnail
  end

  def self.choose_storage
    (Rails.env.production? and Configuration[:aws_access_key]) ? :fog : :file
  end

  storage choose_storage

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def cache_dir
    "#{Rails.root}/tmp/uploads"
  end

  # Ajouter un timestamp au nom de fichier pour invalider le cache S3/CDN
  # lors d'un re-upload (CarrierWave 3.x compatible).
  # - Nouvel upload : original_filename est défini → filename avec timestamp
  # - Lecture fichier existant : original_filename est nil → super retourne
  #   le filename stocké en DB (cf. github.com/carrierwaveuploader/carrierwave/issues/2708)
  def filename
    return super unless original_filename
    @cached_filename ||= begin
      ext = File.extname(original_filename)
      base = File.basename(original_filename, ext).parameterize
      "#{base}_#{Time.now.to_i}#{ext}"
    end
  end

  # Flatten transparency to white before any convert: :jpg (which defaults to
  # black background).  Only applied to PNG/GIF/TIFF; JPEG is left untouched
  # to avoid corruption on some ImageMagick versions.
  process :flatten_alpha

  def flatten_alpha
    manipulate! do |img|
      begin
        if img.path.to_s =~ /\.(png|gif|tiff?)$/i
          img.combine_options do |c|
            c.background "white"
            c.alpha "remove"
          end
        end
      rescue => e
        Rails.logger.warn "[ImageUploader] flatten_alpha failed: #{e.message}"
      end
      img
    end
  end

  process quality: 60
end
