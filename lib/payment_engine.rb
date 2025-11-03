class PaymentEngine
  mattr_accessor :engines
  self.engines = [Neighborly::Mangopay::Creditcard::Interface.new].uniq{|e|e.name}

  def initialize(engine)
    @engine = engine
  end

  def save
    self.engines.push @engine unless self.engines.map(&:name).include?(@engine.name)
  end

  class << self
    def all
      engines.uniq{|e|e.name}
    end

    def destroy_all
      engines.clear
    end

    def create_payment_notification(attributes)
      PaymentNotification.create!(attributes)
    end

    def configuration
      ::Configuration
    end

    def find_payment(filter)
      resource_class = Contribution
      id_key         = filter.slice(:contribution_id, :match_id).keys.first
      if id_key
        filter[:id]    = filter.delete(id_key)
        # :match_id => Match
        resource_class = id_key[0..-4].camelize.constantize
      end
      resource_class.find_by(filter)
    end
  end
end
