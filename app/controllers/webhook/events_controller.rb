module Webhook
  class EventsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      EventReceiver.new(params).process_request
      render nothing: true
    end
  end
end
