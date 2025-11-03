# An order is th PayIn in Mangopay
module Neighborly::Mangopay
  class Order < ActiveRecord::Base
    self.table_name = :neighborly_mangopay_orders

    belongs_to :contribution, class_name: '::Contribution'
    belongs_to :project, class_name: '::Project'
    belongs_to :user, class_name: '::User'

    validates :project, :user, :order_key, presence: true
  end
end
