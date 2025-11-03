require "neighborly/mangopay/creditcard/engine"
require "neighborly/mangopay/creditcard/version"
require "neighborly/mangopay/creditcard/interface"

module Neighborly
  module Mangopay
    module Creditcard
      autoload :Engine,    "neighborly/mangopay/creditcard/engine"
      autoload :Version,   "neighborly/mangopay/creditcard/version"
      autoload :Interface, "neighborly/mangopay/creditcard/interface"      
    end
  end
end
