OpenneoImpressItems::Application.routes.draw do |map|
  match '/' => 'items#index', :as => :items
  match '/:id' => 'items#show', :as => :item
  
  match '/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
  
  match '/species/:species_id/color/:color_id/pet_type.json' => 'pet_types#show'
end
