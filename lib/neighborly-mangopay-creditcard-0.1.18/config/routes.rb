Neighborly::Mangopay::Creditcard::Engine.routes.draw do
  resources :payments,      only: %i(new create update)
  resources :notifications, only: :create
  get '/contribution/:contribution_id/confirm_secured_payment', to: 'payments#confirm_secured_payment', as: 'secured_return'
end
