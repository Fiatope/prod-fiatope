class LovemoneyController < ApplicationController
  def index
    @presenter = LovemoneyPresenter.new(params)
  end
end
