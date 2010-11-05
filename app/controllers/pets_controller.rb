class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, :with => :pet_not_found
  
  DESTINATIONS = {
    'needed_items' => '?',
    'root' => '#',
    'wardrobe' => '#'
  }

  def load
    raise Pet::PetNotFound unless params[:name]
    @pet = Pet.load(params[:name])
    @pet.save
    destination = params[:destination]
    destination = 'root' unless DESTINATIONS[destination]
    query_joiner = DESTINATIONS[destination]
    path = send("#{destination}_path") + query_joiner + @pet.wardrobe_query
    redirect_to path
  end
  
  protected
  
  def pet_not_found
    path = params[:origin] || root_path
    path += "?name=#{params[:name]}"
    redirect_to path, :alert => 'Could not find any pet by that name. Did you spell it correctly?'
  end
end
