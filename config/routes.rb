OpenneoImpressItems::Application.routes.draw do |map|
  get "swf_assets/index"

  match '/' => 'items#index', :as => :items
  match '/:id' => 'items#show', :as => :item
  match '/:item_id/swf_assets.json' => 'swf_assets#index', :as => :item_swf_assets
end
