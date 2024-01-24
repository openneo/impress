class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, with: :pet_not_found
  rescue_from PetType::DownloadError, SwfAsset::DownloadError, with: :asset_download_error
  rescue_from Pet::DownloadError, with: :pet_download_error
  rescue_from Pet::AltStyleNotSupportedYet, with: :alt_style_not_supported_yet

  def load
    return modeling_disabled unless user_signed_in? && current_user.admin?

    raise Pet::PetNotFound unless params[:name]
    @pet = Pet.load(
      params[:name],
      :item_scope => Item.includes(:translations),
    )
    points = contribute(current_user, @pet)
    
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
  
  protected

  def contribute(user, pet)
    if user.present?
      points = user.contribute! pet
    else
      pet.save!
      points = true
    end
    points
  end
  
  def destination
    case (params[:destination] || params[:origin])
      when 'wardrobe'     then wardrobe_path     + '?'
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
        render :json => options[:long_message], :status => options[:status]
      end
    end
  end

  def modeling_disabled
    pet_load_error long_message: t('pets.load.modeling_disabled'),
      status: :forbidden
  end

  def alt_style_not_supported_yet
    pet_load_error(
      long_message: "This pet is using the new Alt Styles feature, which " +
        "we're still working on. Thank you for trying, we'll be ready soon!!",
      status: :bad_request,
    )
  end
end
