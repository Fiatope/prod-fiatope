module ImageProcessing
  def self.included(base)
    if Rails.env.production? || ENV['ENVIRONMENT_NAME']&.casecmp('preproduction') == 0
      base.send :include, CarrierWave::RMagick
    else
      base.send :include, CarrierWave::MiniMagick
    end
  end
end

module CarrierWave
  module RMagick

    def quality(percentage)
      manipulate! do |img|
        img.write(current_path){ |options| options.quality = percentage } unless img.quality == percentage
        img = yield(img) if block_given?
        img
      end
    end

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
