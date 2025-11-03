module Neighborly::Mangopay
  module EventsObserver
    class DebitCanceled

      def perform(event)
        if event.type.eql? 'debit.canceled'
          event.resource.cancel!
        end
      end

    end
  end
end
