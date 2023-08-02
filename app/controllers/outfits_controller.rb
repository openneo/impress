class OutfitsController < ApplicationController
  before_filter :find_authorized_outfit, :only => [:update, :destroy]

  def create
    @outfit = Outfit.build_for_user(current_user, outfit_params)
    if @outfit.save
      render :json => @outfit
    else
      render_outfit_errors
    end
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
        format.html { redirect_to login_path(:return_to => request.fullpath) }
        format.json { render :json => [] }
      end
    end
  end

  def destroy
    @outfit.destroy
    
    respond_to do |format|
      format.html {
        flash[:success] = t('outfits.destroy.success',
                            :outfit_name => @outfit.name)
        redirect_to current_user_outfits_path
      }
      format.json { render :json => true }
    end
  end

  def new
    unless localized_fragment_exist?("outfits#new neopia_online start_from_scratch_form pranks_funny=#{Color.pranks_funny?}") && localized_fragment_exist?("outfits#new neopia_offline start_from_scratch_form pranks_funny=#{Color.pranks_funny?}")
      @colors = Color.funny.alphabetical
      @species = Species.alphabetical
    end
    
    newest_items = Item.newest.select([:id, :updated_at, :thumbnail_url, :rarity_index]).
      includes(:translations).limit(18)
    @newest_modeled_items, @newest_unmodeled_items =
      newest_items.partition(&:predicted_fully_modeled?)

    @newest_unmodeled_items_predicted_missing_species_by_color = {}
    @newest_unmodeled_items_predicted_modeled_ratio = {}
    @newest_unmodeled_items.each do |item|
      h = item.predicted_missing_nonstandard_body_ids_by_species_by_color(
        Color.includes(:translations).select([:id]),
        Species.includes(:translations).select([:id]))
      standard_body_ids_by_species = item.
        predicted_missing_standard_body_ids_by_species(
          Species.select([:id]).includes(:translations))
      if standard_body_ids_by_species.present?
        h[:standard] = standard_body_ids_by_species
      end
      @newest_unmodeled_items_predicted_missing_species_by_color[item] = h
      @newest_unmodeled_items_predicted_modeled_ratio[item] = item.predicted_modeled_ratio
    end

    @species_count = Species.count
    
    unless localized_fragment_exist?('outfits#new latest_contribution')
      @latest_contribution = Contribution.recent.first
      Contribution.preload_contributeds_and_parents([@latest_contribution].compact)
    end

    @neopets_usernames = user_signed_in? ? current_user.neopets_usernames : []

    @campaign = Campaign.current rescue nil
  end

  def show
    @outfit = Outfit.find(params[:id])
    @campaign = Campaign.current rescue nil
    respond_to do |format|
      format.html { render }
      format.json { render :json => @outfit }
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
    if @outfit.update_attributes(outfit_params)
      render :json => @outfit
    else
      render_outfit_errors
    end
  end

  private

  def outfit_params
    params.require(:outfit).permit(
      :name, :pet_state_id, :starred, :worn_and_unworn_item_ids)
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

