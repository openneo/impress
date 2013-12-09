class PetsController < ApplicationController
  rescue_from Pet::PetNotFound, :with => :pet_not_found
  rescue_from PetType::DownloadError, SwfAsset::DownloadError, :with => :asset_download_error
  rescue_from Pet::DownloadError, :with => :pet_download_error

  protect_from_forgery except: :submit
  before_filter :local_only, only: :submit
  
  cache_sweeper :user_sweeper

  def load
    if params[:name] == '!'
      redirect_to roulette_path
    else
      raise Pet::PetNotFound unless params[:name]
      @pet = Pet.load(params[:name], :item_scope => Item.includes(:translations))
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
  end

  def submit
    viewer_data = HashWithIndifferentAccess.new(JSON.parse(params[:viewer_data]))
    @pet = Pet.from_viewer_data(viewer_data, :item_scope => Item.includes(:translations))
    @user = params[:user_id].present? ? User.find(params[:user_id]) : nil
    render json: {points: contribute(@user, @pet)}
  end
  
  protected

  def contribute(user, pet)
    if user.present?
      points = user.contribute! pet
    else
      pet.save!
      points = true
    end
    pet.translate_items
    points
  end
  
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
