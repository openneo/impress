class PetTypesController < ApplicationController
  def show
    pet_type = PetType.find_by_color_id_and_species_id(params[:color_id], params[:species_id])
    raise ActiveRecord::RecordNotFound unless pet_type
    render :json => pet_type
  end
end
