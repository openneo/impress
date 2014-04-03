class ItemZoneSetsController < ApplicationController
  def index
    render :json => Zone.for_items.sets
  end
end
