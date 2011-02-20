class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, :with => :pet_not_found
  rescue_from PetType::DownloadError, SwfAsset::DownloadError, :with => :download_error
  
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
    pet_load_error :long_message => 'Could not find any pet by that name. Did you spell it correctly?',
      :short_message => 'Pet not found',
      :status => :not_found
  end
  
  def download_error(e)
    Rails.logger.warn e.message
    pet_load_error :long_message => "We found the pet all right, but the " +
      "Neopets image server didn't respond to our download request. Maybe it's " +
      "down, or maybe it's just having trouble. Try again later, maybe. Sorry!",
      :short_message => 'Neopets seems down. Try again?',
      :status => :gateway_timeout
  end
  
  def pet_load_error(options)
    respond_to do |format|
      format.html do
        path = params[:origin] || root_path
        path += "?name=#{params[:name]}"
        redirect_to path, :alert => options[:long_message]
      end
      
      format.json do
        render :text => options[:short_message], :status => options[:status]
      end
    end
  end
end
