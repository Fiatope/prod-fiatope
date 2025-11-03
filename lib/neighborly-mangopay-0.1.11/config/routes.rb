Neighborly::Mangopay::Engine.routes.draw do
  resources :notifications, only: :create
  put '/projects/:project_id/payout', to: 'payouts#create', as: :payout_project
end
