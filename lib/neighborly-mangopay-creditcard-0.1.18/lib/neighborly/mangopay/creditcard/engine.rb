module Neighborly
  module Mangopay
    module Creditcard
      class Engine < ::Rails::Engine
        isolate_namespace Neighborly::Mangopay::Creditcard

        initializer :assets do |config|
          # put here the css and js files you want to autoload
          # Rails.application.config.assets.precompile += %w{ }
          # Rails.application.config.assets.precompile += %w{ }
          Rails.application.config.assets.paths << root.join("app", "assets", "images")
        end
      end
    end
  end
end
