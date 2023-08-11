OpenneoImpressItems::Application.routes.draw do
  get "petpages/new"

  get "closet_lists/new"

  get "closet_lists/create"

  root :to => 'outfits#new'

  # DEPRECATED
  get '/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :body_swf_assets
  
  get '/items/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  get '/items/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  get '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets
  get '/pet_types/:pet_type_id/items/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_pet_type
  get '/pet_states/:pet_state_id/swf_assets.json' => 'swf_assets#index', :as => :pet_state_swf_assets
  get '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'

  get '/roulette' => 'roulettes#new', :as => :roulette

  resources :contributions, :only => [:index]
  resources :items, :only => [:index, :show] do
    collection do
      get :needed
    end
  end
  resources :outfits, :only => [:show, :create, :update, :destroy]
  resources :pet_attributes, :only => [:index]
  resources :swf_assets, :only => [:index, :show] do
    collection do
      get :links
    end
  end
  resources :zones, only: [:index]

  scope 'import' do
    resources :neopets_page_import_tasks, only: [:new, :create],
      path: ':page_type/pages/:expected_index'

    resources :neopets_users, :only => [:new, :create], :path => 'neopets-users'
  end

  get '/your-outfits', to: 'outfits#index', as: :current_user_outfits
  get '/users/current-user/outfits', to: redirect('/your-outfits')

  post '/pets/load' => 'pets#load', :as => :load_pet
  post '/pets/submit' => 'pets#submit', :method => :post
  get '/modeling' => 'pets#bulk', :as => :bulk_pets

  devise_for :auth_users
  
  post '/locales/choose' => 'locales#choose', :as => :choose_locale

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

  resources :donations, only: [:create, :show, :update] do
    collection do
      resources :donation_features, path: 'features', only: [:index]
    end
  end

  resources :campaigns, only: [:show], path: '/donate/campaigns'
  get '/donate' => 'campaigns#current', as: :donate

  get 'users/current-user/closet' => 'closet_hangers#index', :as => :your_items

  get 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  get 'users/top_contributors' => redirect('/users/top-contributors')

  get '/wardrobe' => 'outfits#edit', :as => :wardrobe
  get '/start/:color_name/:species_name' => 'outfits#start'

  get 'image-mode' => 'static#image_mode', :as => :image_mode
  get '/terms' => redirect("https://impress-2020.openneo.net/terms"), :as => :terms

  get '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  get '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text
end