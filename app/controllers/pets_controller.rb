class PetsController < ApplicationController
  def show
    @pet = Pet.load(params[:id])
    @pet.save
    redirect_to wardrobe_path(:anchor => @pet.wardrobe_query)
  end
end
