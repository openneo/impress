class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, :with => :pet_not_found
  
  cache_sweeper :user_sweeper
  
  DESTINATIONS = {
    'needed_items' => '?',
    'root' => '#',
    'wardrobe' => '#'
  }

  def load
    if params[:name] == '!'
      redirect_to roulette_path
    else
      raise Pet::PetNotFound unless params[:name]
      @pet = Pet.load(params[:name])
      if user_signed_in?
        points = current_user.contribute! @pet
      else
        @pet.save
        points = true
      end
      respond_to do |format|
        format.html do
          destination = params[:destination] || params[:origin]
          destination = 'root' unless DESTINATIONS[destination]
          query_joiner = DESTINATIONS[destination]
          path = send("#{destination}_path") + query_joiner + @pet.wardrobe_query
          redirect_to path
        end
        
        format.json do
          render :json => points
        end
      end
    end
  end
  
  protected
  
  def pet_not_found
    respond_to do |format|
      format.html do
        path = params[:origin] || root_path
        path += "?name=#{params[:name]}"
        redirect_to path, :alert => 'Could not find any pet by that name. Did you spell it correctly?'
      end
      
      format.json do
        render :text => 'Pet not found', :status => :not_found
      end
    end
  end
end
