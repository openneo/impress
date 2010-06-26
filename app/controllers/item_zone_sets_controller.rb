class ItemZoneSetsController < ApplicationController
  def index
    render :json => Zone::ItemZoneSets.keys.sort.as_json, :callback => params[:callback]
  end
end
