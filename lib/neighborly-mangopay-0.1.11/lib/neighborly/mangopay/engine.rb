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

      # DÉSACTIVÉ - MangoPay n'est plus utilisé (Stripe Connect à la place)
      # Les associations sont conservées pour la compatibilité avec les données existantes
      # mais les fonctionnalités actives sont désactivées
      config.to_prepare do
        # On garde les associations pour accéder aux données historiques
        # mais on désactive les méthodes actives
        ::User.send(:include, Neighborly::Mangopay::User)
        ::Project.send(:include, Neighborly::Mangopay::Project)
        ::Contribution.send(:include, Neighborly::Mangopay::Contribution)
        ::Match.send(:include, Neighborly::Mangopay::Match)
        
        # Afficher un avertissement au démarrage
        Rails.logger.warn "=============================================".yellow rescue nil
        Rails.logger.warn "===================== MangoPay DÉSACTIVÉ - Utilisation de Stripe uniquement =====================".yellow rescue nil
        Rails.logger.warn "=============================================".yellow rescue nil
      end

    end
  end
end
