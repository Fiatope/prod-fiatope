module Webhook
  class EventSenderWorker
    include Sidekiq::Worker
    sidekiq_options retry: 2

    def perform(event_id)
      return # This is not implemented so I put a return here to avoid cluttering the logs.
      EventSender.new(event_id).send_request
    end
  end
end
