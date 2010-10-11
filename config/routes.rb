OpenneoImpressItems::Application.routes.draw do |map|
  match '/' => 'items#index', :as => :items
  match '/index.js' => 'items#index', :format => :js
  match '/items.json' => 'items#index', :format => :json
  match '/items/:id' => 'items#show', :as => :item
 
  match '/item_zone_sets.js' => 'ItemZoneSets#index'
  match '/item_zone_sets.json' => 'ItemZoneSets#index'
  
  match '/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :body_swf_assets
  match '/items/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  match '/items/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  match '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets  
  match '/pet_states/:pet_state_id/swf_assets.json' => 'swf_assets#index', :as => :pet_state_swf_assets
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'
  
  resources :items, :only => [:index]
  resources :pet_attributes, :only => [:index]
  resources :pets, :only => [:show]
  
  match '/wardrobe' => 'outfits#edit', :as => :wardrobe
end
