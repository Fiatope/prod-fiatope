require 'sidekiq/web'

Neighborly::Application.routes.draw do

  get 'mailing_list/addUser'
  get 'challenge/index'

  get 'set_language/french'

  get 'set_language/english'

  #get '/about', to: redirect('/learn')

  post :hooks, to: 'webhook/events#create'

  devise_for :users, path: '',
    path_names:  {
      sign_in:  :login,
      sign_out: :logout,
      sign_up:  :inscription
    },
    controllers: {
      omniauth_callbacks: :omniauth_callbacks,
      sessions:           :sessions,
      registrations: "registrations"
    }


  devise_scope :user do
    post '/sign_up', to: 'devise/registrations#create', as: :sign_up
  end


  get '/thank_you' => "static#thank_you"

  check_user_admin = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.admin }

  # Mountable engines
  constraints check_user_admin do
    mount Sidekiq::Web => '/sidekiq'
  end

  #mount Neighborly::Api::Engine => '/api/', as: :neighborly_api
  #mount Neighborly::Dashboard::Engine => '/dashboard/', as: :neighborly_dashboard
  mount Neighborly::Stripe::Engine => '/stripe/', as: :neighborly_stripe
  # DÉSACTIVÉ - MangoPay n'est plus utilisé (remplacé par Stripe)
  # mount Neighborly::Mangopay::Creditcard::Engine => '/mangopay/creditcard/', as: :neighborly_mangopay_creditcard
  # mount Neighborly::Mangopay::Engine => '/mangopay/', as: :neighborly_mangopay
  #mount Neighborly::Balanced::Creditcard::Engine => '/balanced/creditcard/', as: :neighborly_balanced_creditcard
  #mount Neighborly::Balanced::Bankaccount::Engine => '/balanced/bankaccount/', as: :neighborly_balanced_bankaccount
  #mount Neighborly::Balanced::Engine => '/balanced/', as: :neighborly_balanced

  Blogo::Routes.mount_to(self, at: '/blog')

  #jekyll like blog
  #namespace :blog do
  #resources :articles, path: '', only: [:index, :show]
  #end


  # Non production routes
  if Rails.env.development?
    resources :emails, only: [ :index, :show ]
  end

  # Channels
  constraints ChannelConstraint do
    namespace :channels, path: '' do
      get '/', to: 'profiles#show', as: :profile
      resources :channels_subscribers, only: [:index, :create, :destroy]

      namespace :admin do

        get '/', to: 'dashboard#index', as: :dashboard
        namespace :reports do
          resources :subscriber_reports, only: [ :index ]
        end

        resources :followers, only: [ :index ]

        resources :projects, only: [ :index, :update] do
          member do
            put 'launch'
            put 'reject'
            put 'push_to_draft'
            put 'push_to_request_funds'
            put 'push_to_paid'
            put 'push_to_fraud_suspiscion'
            put 'approve'
            put 'cancel'
          end
        end
      end

      resources :projects, only: [:new, :create]
      # NOTE We use index instead of create to subscribe comming back from auth via GET
      resource :channels_subscriber, only: [:show, :destroy], as: :subscriber
    end
  end

  mount Neighborly::Admin::Engine => '/admin/', as: :neighborly_admin

  # Root path should be after channel constraints
  root to: 'projects#index'

  # Static Pages
  get '/sitemap',               to: 'static#sitemap',             as: :sitemap
  get '/comment-ça-marche',          to: 'static#how_it_works',        as: :how_it_works
  get "/faq",                   to: "static#faq",                 as: :faq
  get "/financement-participatif-en-afrique-le-jackpot-sous-certaines-conditions",                   to: "static#article_financement",                 as: :article_financement
  get "/conditions",                 to: "static#terms",               as: :terms
  get "/privacy",               to: "static#privacy",             as: :privacy
  get "/commencer",                 to: "projects#start",             as: :start
  get "/coaching",              to: "projects#coaching",          as: :coaching
  get "/consulting",              to: "projects#consulting",          as: :consulting 
  get "/développementpro",          to: "static#prodevelopment",    as: :prodevelopment 
  get "/startup-iyem",          to: "static#startupiyem",    as: :startupiyem
  get "/prix-fiatope",          to: "static#prix_fiatope",    as: :prix_fiatope
  get "/fiatope-acceleration",          to: "static#fiatopaccelerator",    as: :fiatopaccelerator
  get "/intervenants",          to: "static#experts",               as: :experts
  get "/training",              to: "static#training",            as: :training
  get "/management",              to: "static#management",            as: :management
  get "/digital",               to: "static#digital",              as: :digital
  get "/ambassadeurs/hirondelle-de-l-avenir",               to: "static#hyrondelle",              as: :hyrondelle 
  get "/crowdfunding",          to: "projects#crowdfunding",      as: :crowdfunding 
  get "/comment-whitelabel", to: "whitelabels#how_it_works",   as: :how_it_works_whitelabel
  get '/learn',                 to: 'static#learn',               as: :learn
  get "/tarifs",                 to: "static#price",               as: :price
  get "/a-propos-de-nous",                 to: "static#about",               as: :about
  get '/pourquoi-fiatope',           to: 'static#why_fiatope',         as: :why_fiatope
  get "/statistics",            to: "discover#statistiques",      as: :statistiques
  get "/csrpartners",          to: "static#csr_partners",        as: :csr_partners
  #get "/partenaires",          to: "static#org_partners",        as: :org_partners
  get "/oser",     to: "static#org_partners_oser",   as: :org_partners_oser
  get "/maeci",    to: "static#org_partners_maeci",  as: :org_partners_maeci
  get "/sélection",            to: "static#selection",          as: :selection
  get "/guide-projets",            to: "static#successful",          as: :successful
  get "/jobs",                  to: "static#jobs",                as: :jobs
  get "/ambassadeurs",           to: "static#ambassadors",         as: :ambassadors
  get "/éthique",         to: "static#values_ethics",       as: :values_ethics
  get "/origine",        to: "static#fiatope_origin",      as: :fiatope_origin
  get "/idée",                  to: "static#idee",                as: :idee      
  get "/développement",           to: "static#development",         as: :development
  get "/lancer",                to: "static#launch",              as: :launch
  get "/culture",               to: "static#culture",             as: :culture
  get "/environnement",         to: "static#env_agri",            as: :env_agri
  get "/renouvelables",          to: "static#renewable",           as: :renewable     
  get "/technologies",          to: "static#technologies",        as: :technologies 
  get "/médecine",              to: "static#medecine",            as: :medecine
  get "/éducation",             to: "static#education",           as: :education
  get "/fiatope-women-challenge",             to: "static#challenge",           as: :challenge

  # Only accessible on development
  if Rails.env.development?
    get "/base",                to: "static#base",              as: :base
  end

  get "/financer-projets/(:state)(/near/:near)(/category/:category)(/tags/:tags)(/search/:search)", to: "discover#index", as: :discover
  get "/suivre-projets/(:state)(/near/:near)(/category/:category)(/tags/:tags)(/search/:search)", to: "tofollow#index", as: :tofollow
  get "/lovemoney/(:state)(/near/:near)(/tags/:tags)(/search/:search)", to: "lovemoney#index", as: :lovemoney
  get "/challenge/", to: "challenge#index", as: :chalenge

  resources :tags, only: [:index]

  # DÉSACTIVÉ - MangoPay n'est plus utilisé
  # get 'cards/:id/delete', to: 'neighborly/mangopay/creditcard/payments#delete'

  namespace :reports do
    resources :contribution_reports_for_project_owners, only: [:index]
  end

  # Temporary
  get '/projects/neuse-river-greenway-benches-draft', to: redirect('/projects/neuse-river-greenway-benches')

  #customer message form
  resources :messages, :only => [ :new, :create] do
     get 'thank_you', :on => :collection
  end
  #end

  #customer whitelabel site creation form
  resources :whitelabels, :only => [ :new, :create] do
     get 'thank_you', :on => :collection
  end
  #end
  
  #women challenge rout

 # get "/challenge", to: "women#challenge", as: :challenge
 # get "/challenge/:challenge" => "women#show"

 post 'webhooks/orange-money-payment-confirmations', to: 'projects/contributions#orange_money_payment_confirmation'
 get  'webhooks/orange-money-payment-confirmations', to: 'projects/contributions#orange_money_payment_confirmation'

  post 'webhooks/pay-plus-africa-payment-confirmations', to: 'projects/contributions#pay_plus_africa_payment_confirmation'
  get  'webhooks/pay-plus-africa-payment-confirmations', to: 'projects/contributions#pay_plus_africa_payment_confirmation'

  resources :projects, except: [ :destroy ] do
    resources :faqs, controller: 'projects/faqs', only: [ :index, :create, :destroy ]
    resources :terms, controller: 'projects/terms', only: [ :index, :create, :destroy ]
    resources :updates, controller: 'projects/updates', only: [ :index, :create, :destroy ]

    collection do
      get 'video'
      resources :build, controller: 'projects/build', as: 'project_build'
    end

    member do
      put :show_project_on_homepage, to: 'neighborly/admin/projects#show_project_on_homepage' 
      put :remove_project_on_homepage, to: 'neighborly/admin/projects#remove_project_on_homepage'
      # Actions Stripe Admin
      put :enable_stripe, to: 'neighborly/admin/projects#enable_stripe'
      put :sync_stripe_account, to: 'neighborly/admin/projects#sync_stripe_account'
      get :stripe_onboarding_link, to: 'neighborly/admin/projects#stripe_onboarding_link'
      put :process_stripe_transfer, to: 'neighborly/admin/projects#process_stripe_transfer'
      put :process_stripe_refund, to: 'neighborly/admin/projects#process_stripe_refund'
      get :verify_stripe_wallet, to: 'neighborly/admin/projects#verify_stripe_wallet'
      get :payout_profile, to: 'neighborly/admin/projects#payout_profile'
      post :unlock_payout_profile_edit, to: 'neighborly/admin/projects#unlock_payout_profile_edit'
    end

    member do
      get 'embed'
      get 'video_embed'
      get 'embed_panel'
      get 'comments'
      get 'reports'
      get 'budget'
      get 'english'
      get 'success'
      get 'pay'
      put 'update_payout_profile'
      post 'request_payout'
      post 'change_recommended'
    end

    resources :rewards, except: :show do
      member do
        post 'sort'
        get 'contribution'
      end
    end

    resources :contributions, controller: 'projects/contributions', except: :update do
      member do
        get 'cancel'
        put 'credits_checkout'
        get 'orange_money_payment_initialization'
        get 'pay_plus_africa_payment_initialization'
        get 'mailing'
        get 'touch_payment_new'
        post 'touch_payment_initialization'
        post 'touch_payment_status'
        get 'touch_payment_pending'
        get 'touch_payment_check_status'
        get 'touch_payment_return'
        post 'touch_payment_return'
      end
    end

    resources :matches, controller: 'projects/matches', except: %i(index update destroy)
  end

  scope :login, controller: :sessions do
    devise_scope :user do
      get   :set_new_user_email
      patch :confirm_new_user_email
    end
  end

  resources :users, path: 'neighbors' do
    resources :questions, controller: 'users/questions', only: [:new, :create]
    resources :projects, controller: 'users/projects', only: [ :index]
    resources :contributions, controller: 'users/contributions', only: [:index] do
      member do
        get :request_refund
        get :tax_receipt
      end
    end

    resources :authorizations, controller: 'users/authorizations', only: [:destroy]
    resources :unsubscribes, only: [:create]
    member do
      get :settings
      get :credits
      get :payments
      # get :mangopay_authentications  # DÉSACTIVÉ - MangoPay n'est plus utilisé
      get :edit
      post :delete_recursive
      put :update_email
      put :update_password
      put :update_bank_information
      # put :mangopay_upload_kyc_files  # DÉSACTIVÉ - MangoPay n'est plus utilisé
    end
  end


  get :contact, to: 'contacts#new'
  resources :contacts, only: [:create]

  resources :images, only: [:new, :create]

  namespace :markdown do
    resources :previewer, only: :create
  end


  # Redirect from old users url to the new
  get "/users/:id", to: redirect('neighbors/%{id}')

  # Temporary Routes
  get '/projects/57/video_embed', to: redirect('projects/ideagarden/video_embed')

  resources :partners, path: "partenaires", only: [:new, :create, :edit, :update, :show] do
    resources :projects, only: [ :index, :show, :approve, :launch, :reject ]

    resources :projects do
      member do
        #delete 'push_to_trash', to: "neighborly/admin/contributions#push_to_trash"
        put 'push_to_draft', to: "neighborly/admin/projects#push_to_draft"
        put 'approve', to: "neighborly/admin/projects#approve"
        put 'launch', to: "neighborly/admin/projects#launch"
        put 'reject', to: "neighborly/admin/projects#reject"
        # Actions Stripe Admin
        put 'enable_stripe', to: "neighborly/admin/projects#enable_stripe"
        put 'sync_stripe_account', to: "neighborly/admin/projects#sync_stripe_account"
        get 'stripe_onboarding_link', to: "neighborly/admin/projects#stripe_onboarding_link"
        put 'process_stripe_transfer', to: "neighborly/admin/projects#process_stripe_transfer"
        put 'process_stripe_refund', to: "neighborly/admin/projects#process_stripe_refund"
        get 'verify_stripe_wallet', to: "neighborly/admin/projects#verify_stripe_wallet"
      end
    end

    collection do
      get :edit, to: "partners#index", as: :edit_all
      get ':id/admin' => 'partners#admin', as: :admin
    end
    
    member do
      get 'commencer', to: redirect('/projects/build/?partner=%{id}')
      get 'admin', to: "partners#admin"
    end
  end

  get "/set_email" => "users#set_email", as: :set_email_users
  get "/:id", to: redirect('projects/%{id}')

  post '/adduser', to: 'mailing_list#addUser'
  put '/removeuser', to: 'mailing_list#removeUser'

end
