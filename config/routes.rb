OpenneoImpressItems::Application.routes.draw do
  root :to => 'outfits#new'

  # Login and account management!
  devise_for :auth_users, path: "users", skip: [:registrations]
  resources :auth_users, only: [:new, :create, :update]
  get '/users/edit', to: 'auth_users#edit', as: 'edit_auth_user'

  # The outfit editor!
  # TODO: It's a bit silly that outfits/new points to outfits#edit.
  # Should we refactor the controller/view structure here?
  get '/outfits/new', to: 'outfits#edit', as: :wardrobe
  get '/wardrobe' => redirect('/outfits/new')
  get '/start/:color_name/:species_name' => 'outfits#start'

  # The outfits users have created!
  resources :outfits, :only => [:show, :create, :update, :destroy]
  get '/your-outfits', to: 'outfits#index', as: :current_user_outfits
  get '/users/current-user/outfits', to: redirect('/your-outfits')

  # Our customization data! Both the item pages, and JSON API endpoints.
  resources :items, only: [:index, :show, :edit, :update] do
    resources :trades, path: 'trades/:type', controller: 'item_trades',
      only: [:index], constraints: {type: /offering|seeking/}

    resources :appearances, controller: 'item_appearances', only: [:index]

    collection do
      get "sources/:ids", action: :sources
      get :latest
    end
  end
  resources :species, only: [] do
    resources :colors, only: [] do
      get :pet_type, to: 'pet_types#show'
    end
    resources :alt_styles, path: 'alt-styles', only: [:index]
  end
  resources :swf_assets, path: 'swf-assets', only: [:show]
  scope "rainbow-pool" do
    resources :alt_styles, path: 'styles', only: [:index, :edit, :update]
  end
  resources :pet_types, path: 'rainbow-pool', param: "name",
            only: [:index, :show] do
    resources :pet_states, only: [:edit, :update], path: "appearances"
  end
  get '/alt-styles', to: redirect('/rainbow-pool/styles')

  # Loading and modeling pets!
  match '/pets/load' => 'pets#load', :as => :load_pet, via: [:get, :post]
  get '/modeling' => 'pets#bulk', :as => :bulk_pets

  # Contributions to our modeling database!
  resources :contributions, :only => [:index]
  get 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  get 'users/top_contributors' => redirect('/users/top-contributors')

  # User resources, like their item lists!
  resources :users, :path => 'user', :only => [:index, :edit, :update] do
    resources :contributions, :only => [:index]
    resources :closet_hangers, :only => [:index, :update, :destroy], :path => 'closet' do
      collection do
        get :petpage
        put :update
        delete :destroy
      end
    end
    resources :closet_lists, :only => [:new, :create, :edit, :update, :destroy], :path => 'closet/lists'

    resources :items, :only => [] do
      resources :closet_hangers, :only => [:create] do
        collection do
          put :update_quantities
        end
      end
    end

    resources :neopets_connections, path: 'neopets-connections',
      only: [:create, :destroy]

    resource :neopass_connection, path: "neopass-connection", only: [:destroy]
  end
  get 'users/current-user/closet' => 'closet_hangers#index', :as => :your_items

  # Importing users' owned items from Neopets.com!
  scope 'import' do
    resources :neopets_page_import_tasks, only: [:new, :create],
      path: ':page_type/pages/:expected_index'
  end

  # Donation campaign stuff!
  scope module: "fundraising", as: "fundraising" do
    resources :donations, only: [:create, :show, :update] do
      collection do
        resources :donation_features, path: 'features', only: [:index]
      end
    end
    resources :campaigns, only: [:show], path: '/donate/campaigns'
  end
  get '/donate' => 'fundraising/campaigns#current', as: :donate

  # About pages!
  get '/terms', to: "about#terms", as: :terms
  get '/privacy',
    to: redirect(Rails.configuration.impress_2020_origin + "/privacy")
  get '/about/neopass',
      to: redirect('https://blog.openneo.net/2024/03/13/neopass-for-dti.html')

  # Admin tools, gated to support staff!
  namespace :admin do
    resources :neologin_cookies, path: "neologin", only: [:index, :create]
  end

  # Other useful lil things!
  get '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  get '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text
  post '/locales/choose' => 'locales#choose', :as => :choose_locale
end
