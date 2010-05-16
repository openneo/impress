OpenneoImpressItems::Application.routes.draw do |map|
  match '/' => 'items#index', :as => :items
  match '/:id' => 'items#show', :as => :item
end
