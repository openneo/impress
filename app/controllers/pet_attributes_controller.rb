class PetAttributesController < ApplicationController
  def index
    render :json => {
      :color => Color.all_ordered_by_name,
      :species => Species.all_ordered_by_name
    }
  end
end
