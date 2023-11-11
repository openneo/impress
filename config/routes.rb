OpenneoImpressItems::Application.routes.draw do
  root :to => 'outfits#new'

  # TODO: It's a bit silly that outfits/new points to outfits#edit.
  # Should we refactor the controller/view structure here?
  get '/outfits/new', to: 'outfits#edit', as: :wardrobe
  get '/wardrobe' => redirect('/outfits/new')
  get '/start/:color_name/:species_name' => 'outfits#start'

  resources :contributions, :only => [:index]
  resources :items, :only => [:index, :show] do
    resources :appearances, controller: 'item_appearances', only: [:index]
    collection do
      get :needed
    end
  end
  resources :outfits, :only => [:show, :create, :update, :destroy]
  resources :pet_attributes, :only => [:index]

  scope 'import' do
    resources :neopets_page_import_tasks, only: [:new, :create],
      path: ':page_type/pages/:expected_index'
  end

  get '/your-outfits', to: 'outfits#index', as: :current_user_outfits
  get '/users/current-user/outfits', to: redirect('/your-outfits')

  post '/pets/load' => 'pets#load', :as => :load_pet
  get '/modeling' => 'pets#bulk', :as => :bulk_pets

  devise_for :auth_users
  
  post '/locales/choose' => 'locales#choose', :as => :choose_locale

  get "petpages/new"
  get "closet_lists/new"
  get "closet_lists/create"

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

  get 'image-mode' => 'static#image_mode', :as => :image_mode
  get '/pardon-our-dust' => 'static#pardon_our_dust', :as => :pardon_our_dust
  get '/terms' => redirect("https://impress-2020.openneo.net/terms"), :as => :terms

  get '/sitemap.xml' => 'sitemap#index', :as => :sitemap, :format => :xml
  get '/robots.txt' => 'sitemap#robots', :as => :robots, :format => :text
end