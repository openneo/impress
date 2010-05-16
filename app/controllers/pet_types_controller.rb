class PetTypesController < ApplicationController
  def show
    pet_type = PetType.find_by_color_id_and_species_id(params[:color_id], params[:species_id])
    render :json => pet_type
  end
end
