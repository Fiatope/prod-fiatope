class ContributionReward < ActiveRecord::Base
  belongs_to :contribution
  belongs_to :reward
end
