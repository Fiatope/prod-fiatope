# Charger la gem Stripe AVANT le module pour éviter conflit namespace
require 'stripe'

require 'neighborly/stripe/engine'
require 'neighborly/stripe/version'
require 'neighborly/stripe/interface'
require 'neighborly/stripe/fee_calculator'

module Neighborly
  module Stripe
    autoload :Engine,             "neighborly/stripe/engine"
    autoload :Version,            "neighborly/stripe/version"
    autoload :Interface,          "neighborly/stripe/interface"
    autoload :FeeCalculator,      "neighborly/stripe/fee_calculator"
    autoload :CampaignSettlement, "neighborly/stripe/campaign_settlement"
    autoload :SyncService,        "neighborly/stripe/sync_service"
  end
end
