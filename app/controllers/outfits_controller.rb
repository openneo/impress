class OutfitsController < ApplicationController
  before_action :find_authorized_outfit, :only => [:update, :destroy]

  def create
    @outfit = Outfit.new(outfit_params)
    @outfit.user = current_user

    if @outfit.save
      render :json => @outfit
    else
      render_outfit_errors
    end
  end

  def edit
    render "outfits/edit", layout: false
  end

  def index
    if user_signed_in?
      @outfits = current_user.outfits.
        includes(:item_outfit_relationships, {:pet_state => :pet_type}).
        wardrobe_order
      respond_to do |format|
        format.html { render }
        format.json { render :json => @outfits }
      end
    else
      respond_to do |format|
        format.html { redirect_to new_auth_user_session_path(:return_to => request.fullpath) }
        format.json { render :json => [] }
      end
    end
  end

  def destroy
    @outfit.destroy
    
    respond_to do |format|
      format.html {
        flash[:notice] = t('outfits.destroy.success',
                            :outfit_name => @outfit.name)
        redirect_to current_user_outfits_path
      }
      format.json { render :json => true }
    end
  end

  def new
    @colors = Color.funny.alphabetical
    @species = Species.alphabetical
    
    newest_items = Item.newest.select([:id, :updated_at, :thumbnail_url, :rarity_index]).
      includes(:translations).limit(18)
    @newest_modeled_items, @newest_unmodeled_items =
      newest_items.partition(&:predicted_fully_modeled?)

    @newest_unmodeled_items_predicted_missing_species_by_color = {}
    @newest_unmodeled_items_predicted_modeled_ratio = {}
    @newest_unmodeled_items.each do |item|
      h = item.predicted_missing_nonstandard_body_ids_by_species_by_color(
        Color.includes(:translations),
        Species.includes(:translations))
      standard_body_ids_by_species = item.
        predicted_missing_standard_body_ids_by_species(
          Species.includes(:translations))
      if standard_body_ids_by_species.present?
        h[:standard] = standard_body_ids_by_species
      end
      @newest_unmodeled_items_predicted_missing_species_by_color[item] = h
      @newest_unmodeled_items_predicted_modeled_ratio[item] = item.predicted_modeled_ratio
    end

    @species_count = Species.count
    
    @latest_contribution = Contribution.recent.first
    Contribution.preload_contributeds_and_parents([@latest_contribution].compact)

    @neopets_usernames = user_signed_in? ? current_user.neopets_usernames : []

    @campaign = Campaign.current rescue nil
  end

  def show
    @outfit = Outfit.find(params[:id])

    respond_to do |format|
      format.html { render "outfits/edit", layout: false }
      format.json { render json: @outfit }
    end
  end
  
  def start
    # Start URLs are always in English, so let's make sure we search in
    # English.
    I18n.locale = I18n.default_locale
    
    @species = Species.find_by_name params[:species_name]
    @color = Color.find_by_name params[:color_name]
    
    if @species && @color
      redirect_to wardrobe_path(:species => @species.id, :color => @color.id)
    else
      not_found('species/color')
    end
  end

  def update
    if @outfit.update(outfit_params)
      render :json => @outfit
    else
      render_outfit_errors
    end
  end

  private

  def outfit_params
    params.require(:outfit).permit(
      :name, :starred, item_ids: {worn: [], closeted: []},
      biology: [:species_id, :color_id, :pose])
  end

  def find_authorized_outfit
    raise ActiveRecord::RecordNotFound unless user_signed_in?
    @outfit = current_user.outfits.find(params[:id])
  end

  def render_outfit_errors
    render :json => {:errors => @outfit.errors,
                     :full_error_messages => @outfit.errors.full_messages},
           :status => :bad_request
  end
end

