CarrierWave.configure do |config|
  if Rails.env.development? || Rails.env.test? || Rails.env.cucumber?
    config.storage = :file
    config.enable_processing = false
  end

  if (Rails.env.production? || Rails.env.staging?) and ENV['AWS_ACCESS_KEY']
    config.storage = :fog
    config.fog_provider = 'fog/aws'
    config.fog_credentials = {
      provider:              'AWS',
      aws_access_key_id:     ENV['AWS_ACCESS_KEY'],
      aws_secret_access_key: ENV['AWS_SECRET_KEY'],
      region:                ENV['AWS_REGION'],
    }
    config.cache_dir     = "#{Rails.root}/tmp/uploads"
    config.fog_directory  = ENV['AWS_BUCKET']
    config.fog_public     = true
    config.fog_attributes = { 'Cache-Control' => 'max-age=315576000' }
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
