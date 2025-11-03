events_observer_payin_canceled = Neighborly::Mangopay::EventsObserver::DebitCanceled.new
Neighborly::Mangopay::Event.add_observer(events_observer_payin_canceled, :perform)
