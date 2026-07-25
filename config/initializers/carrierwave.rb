CarrierWave.configure do |config|
  config.cache_dir = "#{Rails.root}/tmp/uploads"
  
  if Rails.env.development? || Rails.env.test? || Rails.env.cucumber?
    # En développement, utiliser le filesystem local par défaut
    # MAIS permettre AWS S3 si les credentials sont configurés
    if ENV['AWS_ACCESS_KEY'].present? && ENV['AWS_REGION'].present?
      Rails.logger.info "CarrierWave: AWS S3 configuré en développement"
      config.storage = :fog
      config.enable_processing = true  # Activer le processing pour tester
      config.fog_provider = 'fog/aws'
      
      config.fog_credentials = {
        provider:              'AWS',
        aws_access_key_id:     ENV['AWS_ACCESS_KEY'],
        aws_secret_access_key: ENV['AWS_SECRET_KEY'],
        region:                ENV['AWS_REGION'],
      }
      
      config.fog_directory  = ENV['AWS_BUCKET']
      config.fog_public     = true
      config.fog_attributes = { 
        'Cache-Control' => 'max-age=3600, public',
        'acl' => 'public-read'  # Forcer ACL public
      }
    else
      config.storage = :file
      config.enable_processing = true  # Toujours activer le processing
    end
  end

  if (Rails.env.production? || Rails.env.staging?) and ENV['AWS_ACCESS_KEY']
    config.storage = :fog
    config.enable_processing = true
    config.fog_provider = 'fog/aws'
    
    config.fog_credentials = {
      provider:              'AWS',
      aws_access_key_id:     ENV['AWS_ACCESS_KEY'],
      aws_secret_access_key: ENV['AWS_SECRET_KEY'],
      region:                ENV['AWS_REGION'],
    }
    
    config.fog_directory  = ENV['AWS_BUCKET']
    config.fog_public     = true
    
    # Forcer les fichiers publics avec ACL
    config.fog_attributes = { 
      'Cache-Control' => 'max-age=3600, public',
      'acl' => 'public-read'
    }
  end
end

module CarrierWave
  module MiniMagick

    def quality(percentage)
      manipulate! do |img|
        img.quality(percentage.to_s)
        img = yield(img) if block_given?
        img
      end
    end

  end
end
