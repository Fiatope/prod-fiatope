module Neighborly::Mangopay
  class RegisteredCard  < ActiveRecord::Base
    self.table_name = :mangopay_registered_cards
    belongs_to :user, class_name: '::User'
    validates :key, presence: true
  end
end
