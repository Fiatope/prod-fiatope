#require 'carrierwave/processing/mime_types'

module Neighborly::Mangopay
  class KycUploader < CarrierWave::Uploader::Base
    include CarrierWave::MiniMagick
    #include CarrierWave::MimeTypes

    def extension_white_list
      %w(jpg jpeg gif png pdf)
    end

    def self.choose_storage
      (Rails.env.production? and ENV['AWS_ACCESS_KEY']) ? :fog : :file
    end

    def store_dir
      "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end

    def cache_dir
      "#{Rails.root}/tmp/uploads/kycs"
    end

    storage choose_storage

    #process :set_content_type

    version :thumb, if: :image? do
      process :quality => 60
      process resize_and_pad: [170, 85]
    end

    protected

    def pdf?(new_file)
      new_file.content_type.include? "/pdf"
    end

    def image?(new_file)
      new_file.content_type.start_with? 'image'
    end
  end
end
