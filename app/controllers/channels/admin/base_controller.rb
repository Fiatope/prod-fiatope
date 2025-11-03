module Channels::Admin
  class BaseController < ApplicationController
    inherit_resources

    before_action do
      authorize channel, :admin?
    end
  end
end
