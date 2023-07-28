class ZonesController < ApplicationController
  def index
    render json: Zone.includes(:translations).all
  end
end
