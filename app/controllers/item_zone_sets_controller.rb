class ItemZoneSetsController < ApplicationController
  def index
    render :json => Zone.all_plain_labels
  end
end
