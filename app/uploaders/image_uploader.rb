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
  # lors d'un re-upload. Sans cela, le navigateur sert l'ancienne image
  # depuis son cache (Cache-Control: max-age=315576000).
  # Mémoisation obligatoire: filename est appelé plusieurs fois par upload
  # (une fois par version), le timestamp doit rester identique.
  def filename
    if original_filename.present?
      @cached_filename ||= begin
        ext = File.extname(original_filename)
        base = File.basename(original_filename, ext).parameterize
        "#{base}_#{Time.now.to_i}#{ext}"
      end
    end
  end

  process quality: 60
end
