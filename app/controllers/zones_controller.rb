class ZonesController < ApplicationController
  def index
    render json: Zone.all
  end
end
