class ChannelMember < ActiveRecord::Base
  belongs_to :channel
  belongs_to :user
  validates :user_id, :channel_id, presence: true
  validates :user_id, :uniqueness => { :scope => :channel_id }
end
