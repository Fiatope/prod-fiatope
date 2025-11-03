# module MangopayCardsPatch
#   def self.included(base)
#     base.send(:include, InstanceMethods)

#     base.class_eval do
#       alias_method :registered_cards, :registered_cards_with_patch
#     end
#   end
  
#   module InstanceMethods
#     def registered_cards_with_patch
#       Neighborly::Mangopay::RegisteredCard.none
#     end
#   end
# end

# unless Neighborly::Mangopay::User.included_modules.include? MangopayCardsPatch
#   Neighborly::Mangopay::User.send(:include, MangopayCardsPatch)
# end
