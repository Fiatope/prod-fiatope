module YAML
  class << self
    alias_method :load, :unsafe_load if YAML.respond_to? :unsafe_load
  end
end

Psych::ClassLoader::ALLOWED_PSYCH_CLASSES = [Time]

module Psych
  class ClassLoader
    ALLOWED_PSYCH_CLASSES = [] unless defined?(ALLOWED_PSYCH_CLASSES)

    class Restricted < ClassLoader
      def initialize(classes, symbols)
        @classes = classes + Psych::ClassLoader::ALLOWED_PSYCH_CLASSES.map(&:to_s)
        @symbols = symbols
        super()
      end
    end
  end
end
