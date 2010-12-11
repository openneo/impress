class ItemZoneSetsController < ApplicationController
  caches_page :index
  
  def index
    render :json => Zone::ItemZoneSets.keys.sort.as_json
  end
end
