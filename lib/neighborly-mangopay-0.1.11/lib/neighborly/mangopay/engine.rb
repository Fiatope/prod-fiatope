module Neighborly
  module Mangopay
    class Engine < ::Rails::Engine
      isolate_namespace Neighborly::Mangopay

      initializer :append_migrations do |app|
        unless app.root.to_s.match root.to_s
          config.paths["db/migrate"].expanded.each do |expanded_path|
            app.config.paths["db/migrate"] << expanded_path
          end
        end
      end

      config.autoload_paths += Dir["#{config.root}/app/observers/**/"]

      config.to_prepare do
        ::User.send(:include, Neighborly::Mangopay::User)
        ::Project.send(:include, Neighborly::Mangopay::Project)
        ::Contribution.send(:include, Neighborly::Mangopay::Contribution)
        ::Match.send(:include, Neighborly::Mangopay::Match)
      end

    end
  end
end
