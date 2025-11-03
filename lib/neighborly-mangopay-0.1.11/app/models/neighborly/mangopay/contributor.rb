module Neighborly::Mangopay
  class Contributor < ActiveRecord::Base
    self.table_name = :mangopay_contributors

    # The class_name is needed because Ruby tries
    # to get this User constant inside
    # Neighborly::Mangopay module.
    belongs_to :user, class_name: '::User'
    has_many :projects, through: :user
  end
end
