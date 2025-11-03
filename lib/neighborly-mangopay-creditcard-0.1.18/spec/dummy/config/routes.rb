Rails.application.routes.draw do
  mount Neighborly::Mangopay::Creditcard::Engine => '/', as: :neighborly_mangopay_creditcard

  resources :projects do
    resources :contributions
    resources :matches
  end
end
