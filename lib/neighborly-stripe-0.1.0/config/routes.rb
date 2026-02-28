Neighborly::Stripe::Engine.routes.draw do
  post 'connect/create', to: 'connect#create_account', as: :connect_create
  post 'connect/link_existing', to: 'connect#link_existing_account', as: :connect_link_existing
  get 'connect/find_existing', to: 'connect#find_existing_account', as: :connect_find_existing
  get 'connect/refresh', to: 'connect#refresh', as: :connect_refresh
  get 'connect/return', to: 'connect#return_url', as: :connect_return
  get 'connect/dashboard', to: 'connect#dashboard', as: :connect_dashboard
  post 'connect/sync', to: 'connect#sync_account', as: :sync_account
  post 'connect/unlink', to: 'connect#unlink_account', as: :connect_unlink
  
  scope '/projects/:project_id' do
    get 'payments/new', to: 'payments#new', as: :payment_new
    post 'payments', to: 'payments#create', as: :payment_create
    get 'payments/success', to: 'payments#success', as: :payment_success
    get 'payments/cancel', to: 'payments#cancel', as: :payment_cancel
  end
  
  post 'webhooks', to: 'webhooks#create', as: :webhooks
end
