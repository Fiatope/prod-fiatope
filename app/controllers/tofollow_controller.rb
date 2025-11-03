class TofollowController < ApplicationController
  def index
    @presenter = TofollowPresenter.new(params)
  end
end
