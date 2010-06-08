OpenneoImpressItems::Application.routes.draw do |map|
  match '/' => 'items#index', :as => :items
  match '/:id' => 'items#show', :as => :item
  
  match '/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  match '/:item_id/bodies/:body_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets_for_body_id
  match '/pet_types/:pet_type_id/swf_assets.json' => 'swf_assets#index', :as => :pet_type_swf_assets
  
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'
end
