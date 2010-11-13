OpenneoImpressItems::Application.routes.draw do |map|
  root :to => 'outfits#new'
  match '/' => 'items#index', :as => :items
  match '/index.js' => 'items#index', :format => :js
  match '/items.json' => 'items#index', :format => :json
 
  match '/item_zone_sets.js' => 'ItemZoneSets#index'
  match '/item_zone_sets.json' => 'ItemZoneSets#index'
  
  match '/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :body_swf_assets
  match '/items/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  match '/items/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  match '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets  
  match '/pet_states/:pet_state_id/swf_assets.json' => 'swf_assets#index', :as => :pet_state_swf_assets
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'
  
  resources :contributions, :only => [:index]
  resources :items, :only => [:index, :show] do
    collection do
      get :needed
    end
  end
  resources :outfits, :only => [:show, :create, :update, :destroy]
  resources :pet_attributes, :only => [:index]
  
  match '/users/current-user/outfits.json' => 'outfits#for_current_user'
  
  match '/pets/load' => 'pets#load', :method => :post, :as => :load_pet
  match '/pets/bulk' => 'pets#bulk', :as => :bulk_pets
  
  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/users/authorize' => 'sessions#create'
  
  resources :user, :only => [] do
    resources :contributions, :only => [:index]
  end
  match 'users/top-contributors' => 'users#top_contributors', :as => :top_contributors
  match 'users/top_contributors' => redirect('/users/top-contributors')
  
  match '/wardrobe' => 'outfits#edit', :as => :wardrobe
  
  match '/terms' => 'static#terms', :as => :terms
end
