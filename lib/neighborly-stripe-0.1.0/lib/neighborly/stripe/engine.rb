module Neighborly
  module Stripe
    class Engine < ::Rails::Engine
      isolate_namespace Neighborly::Stripe

      initializer :append_migrations do |app|
        unless app.root.to_s.match root.to_s
          config.paths["db/migrate"].expanded.each do |expanded_path|
            app.config.paths["db/migrate"] << expanded_path
          end
        end
      end

      config.autoload_paths += Dir["#{config.root}/app/workers/**/"]

      config.to_prepare do
        ::User.send(:include, Neighborly::Stripe::User)
        ::Project.send(:include, Neighborly::Stripe::Project)
        ::Contribution.send(:include, Neighborly::Stripe::Contribution)
        
        # Enregistrer Stripe dans PaymentEngine
        PaymentEngine.new(Neighborly::Stripe::Interface.new).save
      end

    end
  end
end
