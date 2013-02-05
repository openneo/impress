class ItemZoneSetsController < ApplicationController
  def index
    render :json => Zone.for_items.all_plain_labels
  end
end
