OpenneoImpressItems::Application.routes.draw do |map|
  match '/' => 'items#index', :as => :items
end
