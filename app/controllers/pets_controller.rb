class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, :with => :pet_not_found
  rescue_from PetType::DownloadError, SwfAsset::DownloadError, :with => :asset_download_error
  rescue_from Pet::DownloadError, :with => :pet_download_error
  
  cache_sweeper :user_sweeper

  def load
    if params[:name] == '!'
      redirect_to roulette_path
    else
      raise Pet::PetNotFound unless params[:name]
      @pet = Pet.load(params[:name], :item_scope => Item.includes(:translations))
      if user_signed_in?
        points = current_user.contribute! @pet
      else
        @pet.save
        points = true
      end
      
      @pet.translate_items
      
      respond_to do |format|
        format.html do
          path = destination + @pet.wardrobe_query
          redirect_to path
        end
        
        format.json do
          render :json => {:points => points, :query => @pet.wardrobe_query}
        end
      end
    end
  end
  
  protected
  
  def destination
    case (params[:destination] || params[:origin])
      when 'wardrobe'     then wardrobe_path     + '#'
      when 'needed_items' then needed_items_path + '?'
      else                     root_path         + '#'
    end
  end
  
  def pet_not_found
    pet_load_error :long_message => t('pets.load.not_found'),
                   :status => :not_found
  end
  
  def asset_download_error(e)
    Rails.logger.warn e.message
    pet_load_error :long_message => t('pets.load.asset_download_error'),
                   :status => :gateway_timeout
  end
  
  def pet_download_error(e)
    Rails.logger.warn e.message
    Rails.logger.warn e.backtrace.join("\n")
    pet_load_error :long_message => t('pets.load.pet_download_error'),
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
        render :text => options[:long_message], :status => options[:status]
      end
    end
  end
end
