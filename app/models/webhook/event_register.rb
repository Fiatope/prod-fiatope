module Webhook
  class EventRecordSerializer
    include ActiveModel::Serialization

    def initialize(record)
      @record = record
    end

    def attributes
      @record.to_hash
    end
  end

  class EventRegister
    attr_accessor :event

    def initialize(record, created: false)
      @record, @created = record, created
      @event = Event.create(serialized_record: serialized_record, kind: type)

      unless Configuration[:disable_webhook] == '1'
        EventSenderWorker.perform_async(@event.id)
      end
    end

    def serialized_record
      @event_record = EventRecordSerializer.new(@record).as_json
      # @event_record.merge(:root => false)
    end

    def type
      action = @created ? 'created' : 'updated'

      [@record.class.model_name.param_key, action].join('.')
    end
  end
end
