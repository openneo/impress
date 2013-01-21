class PetAttributesController < ApplicationController
  def index
    render :json => {
      :color => Color.all_ordered_by_name,
      :species => Species.alphabetical
    }
  end
end
