class PetAttributesController < ApplicationController
  def index
    render :json => {
      :color => Color.alphabetical,
      :species => Species.alphabetical
    }
  end
end
