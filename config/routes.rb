OpenneoImpressItems::Application.routes.draw do
  root :to => 'outfits#new'

  # Login and account management!
  devise_for :auth_users

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
  resources :items, :only => [:index, :show] do
    resources :appearances, controller: 'item_appearances', only: [:index]
    collection do
      get :needed
    end
  end
  resources :species do
    resources :colors do
      get :pet_type, to: 'pet_types#show'
    end
  end

  # Loading and modeling pets!
  post '/pets/load' => 'pets#load', :as => :load_pet
  get '/modeling' => 'pets#bulk', :as => :bulk_pets

  # Contributions to our modeling database!
  resources :contributions, :only => [:index]
  get 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  get 'users/top_contributors' => redirect('/users/top-contributors')

  # User resources, like their item lists!
  resources :users, :path => 'user', :only => [:index, :update] do
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
  end
  get 'users/current-user/closet' => 'closet_hangers#index', :as => :your_items

  # Importing users' owned items from Neopets.com!
  scope 'import' do
    resources :neopets_page_import_tasks, only: [:new, :create],
      path: ':page_type/pages/:expected_index'
  end

  # Donation campaign stuff!
  resources :donations, only: [:create, :show, :update] do
    collection do
      resources :donation_features, path: 'features', only: [:index]
    end
  end
  resources :campaigns, only: [:show], path: '/donate/campaigns'
  get '/donate' => 'campaigns#current', as: :donate

  # Static pages!
  get '/pardon-our-dust' => 'static#pardon_our_dust', :as => :pardon_our_dust
  get '/terms' => redirect("https://impress-2020.openneo.net/terms"), :as => :terms

  # Other useful lil things!
  get '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  get '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text
  post '/locales/choose' => 'locales#choose', :as => :choose_locale
end