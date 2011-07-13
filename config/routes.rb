OpenneoImpressItems::Application.routes.draw do |map|
  root :to => 'outfits#new'

  devise_for :users

  match '/item_zone_sets.json' => 'ItemZoneSets#index'

  match '/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :body_swf_assets
  match '/items/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  match '/items/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  match '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets
  match '/pet_states/:pet_state_id/swf_assets.json' => 'swf_assets#index', :as => :pet_state_swf_assets
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'

  match '/roulette' => 'roulettes#new', :as => :roulette

  resources :contributions, :only => [:index]
  resources :items, :only => [:index, :show] do
    collection do
      get :needed
    end
  end
  resources :outfits, :only => [:show, :create, :update, :destroy]
  resources :pet_attributes, :only => [:index]
  resources :swf_assets, :only => [:index, :show]

  resources :closet_pages, :only => [:new, :create], :path => 'closet/pages'

  match '/users/current-user/outfits' => 'outfits#index', :as => :current_user_outfits

  match '/pets/load' => 'pets#load', :method => :post, :as => :load_pet
  match '/pets/bulk' => 'pets#bulk', :as => :bulk_pets

  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/users/authorize' => 'sessions#create'

  resources :user, :only => [] do
    resources :contributions, :only => [:index]
    resources :closet_hangers, :only => [:index], :path => 'closet'
  end

  match 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  match 'users/top_contributors' => redirect('/users/top-contributors')

  match '/wardrobe' => 'outfits#edit', :as => :wardrobe

  match '/donate' => 'static#donate', :as => :donate
  match 'image-mode' => 'static#image_mode', :as => :image_mode
  match '/terms' => 'static#terms', :as => :terms

  match '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  match '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text
end

