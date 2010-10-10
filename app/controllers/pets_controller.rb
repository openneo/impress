class PetsController < ActionController::Base
  def show
    @pet = Pet.load(params[:id])
    @pet.save
    redirect_to @pet.wardrobe_url
  end
end
