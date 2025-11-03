module Neighborly::Mangopay
  class ProjectWalletHandler < ActiveRecord::Base
    self.table_name = :mangopay_wallet_handlers

    belongs_to :project, class_name: '::Project'
    validates :wallet_key, presence: true
  end
end
