require 'observer'

module Neighborly::Mangopay
  class Event
    extend Observable

    TYPES = %w(debit.canceled
               debit.created
               debit.succeeded
              )

    def initialize(request_params)
      @request_params = request_params
    end

    def save
      return unless valid?

      if resource.present?
        key = "#{ActiveModel::Naming.param_key(resource)}_id".to_sym
        PaymentEngine.create_payment_notification(
          key         => resource.id,
          extra_data: @request_params.to_json
        )
      end

      self.class.changed
      self.class.notify_observers(self)
    end

    def valid?
      valid_type? or return false

      {
        'debit.created'                       => -> { values_matches? },
        'debit.succeeded'                     => -> { values_matches? },
        'debit.canceled'                      => -> { values_matches? }
      }.fetch(type).call
    end

    def resource
      payment_id = entity_params.fetch(:id)
      return false unless payment_id

      resource = Contribution.find_by(payment_id: payment_id)
      unless resource.present?
        resource = Match.find_by(payment_id: payment_id)
      end
      resource
    end

    def type
      @request_params.fetch(:events).last.fetch(:type)
    end

    def entity_href
      entity_params.fetch(:href)
    end

    def contributor
      Neighborly::Mangopay::Contributor.find_by(key: user_key)
    end

    def user
      contributor.try(:user) || resource.try(:user)
    end

    protected

    def valid_type?
      TYPES.include? type
    end

    def values_matches?
      resource.try(:price_in_cents).eql?(payment_amount)
    end

    def payment_amount
      entity_params.fetch(:amount).to_i
    end

    def verification?
      !!type['bank_account_verification']
    end

    def bank_account_href
      if verification?
        "/bank_accounts/#{entity_params.fetch(:links).fetch(:bank_account)}"
      end
    end

    def entity_params
      entity_type = type.split('.').first.pluralize
      @request_params.fetch(:events).last.fetch(:entity).fetch(entity_type).last
    end
  end
end
