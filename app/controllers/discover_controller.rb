class DiscoverController < ApplicationController
  def index
    @presenter = DiscoverPresenter.new(params.to_unsafe_h)
  end
end
