class PetAttributesController < ApplicationController
  def index
    render :json => {
      :color => Color.all,
      :species => Species.all
    }
  end
end
