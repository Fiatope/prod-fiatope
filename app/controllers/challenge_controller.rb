class ChallengeController < ApplicationController
  def index
    @presenter = ChallengePresenter.new(params)
  end
end
