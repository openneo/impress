class PetAttributesController < ApplicationController
  def index
    render :json => {
      :color => Color.funny.alphabetical,
      :species => Species.alphabetical
    }
  end
end
