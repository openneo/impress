require 'resque/server'

OpenneoImpressItems::Application.routes.draw do
  get "petpages/new"

  get "closet_lists/new"

  get "closet_lists/create"

  root :to => 'outfits#new'

  devise_for :users

  # DEPRECATED
  match '/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :body_swf_assets
  
  match '/items/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  match '/items/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  match '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets
  match '/pet_types/:pet_type_id/items/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_pet_type
  match '/pet_states/:pet_state_id/swf_assets.json' => 'swf_assets#index', :as => :pet_state_swf_assets
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'

  match '/roulette' => 'roulettes#new', :as => :roulette

  resources :broken_image_reports, :only => [:new, :create]
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
    resources :closet_pages, :only => [:new, :create],
      :controller => 'neopets_pages', :path => 'closet/pages', :type => 'closet'

    resources :safety_deposit_pages, :only => [:new, :create],
      :controller => 'neopets_pages', :path => 'sdb/pages', :type => 'sdb'

    resources :neopets_users, :only => [:new, :create], :path => 'neopets-users'
  end

  match '/users/current-user/outfits' => 'outfits#index', :as => :current_user_outfits

  match '/pets/load' => 'pets#load', :method => :post, :as => :load_pet
  match '/pets/submit' => 'pets#submit', :method => :post
  match '/modeling' => 'pets#bulk', :as => :bulk_pets

  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/users/authorize' => 'sessions#create'
  
  match '/locales/choose' => 'locales#choose', :as => :choose_locale

  resources :users, :path => 'user', :only => [:index, :update] do
    resources :contributions, :only => [:index]
    resources :closet_hangers, :only => [:index, :update, :destroy], :path => 'closet' do
      collection do
        get :petpage
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

  match 'users/current-user/closet' => 'closet_hangers#index', :as => :your_items

  match 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  match 'users/top_contributors' => redirect('/users/top-contributors')

  match '/wardrobe' => 'outfits#edit', :as => :wardrobe
  match '/start/:color_name/:species_name' => 'outfits#start'

  match '/donate' => 'static#donate', :as => :donate
  match 'image-mode' => 'static#image_mode', :as => :image_mode
  match '/terms' => 'static#terms', :as => :terms

  match '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  match '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text

  def mount_resque
    mount Resque::Server, :at => '/resque'
  end

  if Rails.env.development?
    mount_resque
  else
    authenticated :user, lambda { |u| u.admin? } do
      mount_resque
    end
  end
end