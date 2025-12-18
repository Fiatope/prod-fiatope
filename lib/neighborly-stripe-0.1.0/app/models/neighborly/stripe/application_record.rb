module Neighborly
  module Stripe
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
