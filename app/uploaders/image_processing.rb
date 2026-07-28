# CRITICAL: This file's name shadows the 'image_processing' gem in $LOAD_PATH.
# We MUST load the real gem first, otherwise ImageProcessing::Chainable is never
# defined and CarrierWave::MiniMagick crashes on boot.
if defined?(Gem) && Gem.loaded_specs['image_processing']
  gem_main = File.join(Gem.loaded_specs['image_processing'].full_gem_path, 'lib', 'image_processing.rb')
  load gem_main unless defined?(::ImageProcessing::Chainable)
end

module FiatopeImageProcessing
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
