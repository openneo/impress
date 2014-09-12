class ItemsController < ApplicationController
  before_filter :set_query
  rescue_from Item::Search::Error, :with => :search_error

  def index
    if @query
      begin
        if params[:per_page]
          per_page = params[:per_page].to_i
          per_page = 50 if per_page && per_page > 50
        else
          per_page = 30
        end
        # Note that we sort by name by hand, since we might have to use
        # fallbacks after the fact
        @items = @query.paginate(page: params[:page], per_page: per_page)
        assign_closeted!
        respond_to do |format|
          format.html {
            @campaign = Campaign.current rescue nil
            if @items.total_count == 1
              redirect_to @items.first
            else
              @items.prepare_partial(:item_link_partial)
              render
            end
          }
          format.json {
            @items.prepare_method(:as_json)
            render json: {items: @items, total_pages: @items.total_pages,
                          query: @query.to_s}
          }
          format.js {
            @items.prepare_method(:as_json)
            render json: {items: @items, total_pages: @items.total_pages,
                          query: @query.to_s},
                   callback: params[:callback]
          }
        end
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.build_proxies(params[:ids])
      assign_closeted!
      @items.prepare_method(:as_json)
      respond_to do |format|
        format.json { render json: @items }
      end
    else
      respond_to do |format|
        format.html {
          @campaign = Campaign.current rescue nil
          unless localized_fragment_exist?('items#index newest_items')
            @newest_items = Item.newest.includes(:translations).limit(18)
          end
        }
        format.js { render json: {error: '$q required'}}
      end
    end
  end

  def show
    @item = Item.find params[:id]

    respond_to do |format|
      format.html do
        unless localized_fragment_exist?("items/#{@item.id} info")
          @occupied_zones = @item.occupied_zones(
            scope: Zone.includes_translations.alphabetical
          )
          @restricted_zones = @item.restricted_zones(
            scope: Zone.includes_translations.alphabetical
          )
        end
        
        unless localized_fragment_exist?("items/#{@item.id} contributors")
          @contributors_with_counts = @item.contributors_with_counts
        end

        @supported_species_ids = @item.supported_species_ids
        unless localized_fragment_exist?("items/show standard_species_images special_color=#{@item.special_color_id}")
          @basic_colored_pet_types_by_species_id = PetType.special_color_or_basic(@item.special_color).includes_child_translations.group_by(&:species)
        end

        @trading_closet_hangers_by_owned = {
          true => @item.closet_hangers.owned_trading.newest.includes(:user),
          false => @item.closet_hangers.wanted_trading.newest.includes(:user)
        }

        if user_signed_in?
          # Empty arrays are important so that we can loop over this and still
          # show the generic no-list case
          @current_user_lists = {true => [], false => []}
          current_user.closet_lists.alphabetical.each do |list|
            @current_user_lists[list.hangers_owned] << list
          end
          
          @current_user_quantities = Hash.new(0) # default is zero
          hangers = current_user.closet_hangers.where(item_id: @item.id).
            select([:owned, :list_id, :quantity])
            
          hangers.each do |hanger|
            key = hanger.list_id || hanger.owned
            @current_user_quantities[key] = hanger.quantity
          end
        end

      end

      format.gif do
        expires_in 1.month
        redirect_to @item.thumbnail_url
      end
    end
  end

  def needed
    if params[:color] && params[:species]
      @pet_type = PetType.find_by_color_id_and_species_id(
        params[:color],
        params[:species]
      )
    end
    
    unless @pet_type
      raise ActiveRecord::RecordNotFound, 'Pet type not found'
    end
    
    @items = @pet_type.needed_items.includes(:translations).
      alphabetize_by_translations
    assign_closeted!
    
    respond_to do |format|
      format.html { @pet_name = params[:name] ; render :layout => 'application' }
      format.json { render :json => @items }
    end
  end

  protected

  def assign_closeted!
    current_user.assign_closeted_to_items!(@items) if user_signed_in?
  end
  
  def search_error(e)
    @items = []
    respond_to do |format|
      format.html { flash.now[:alert] = e.message; render }
      format.json { render :json => {error: e.message} }
      format.js   { render :json => {error: e.message},
                           :callback => params[:callback] }
    end
  end

  def set_query
    q = params[:q]
    if q.is_a?(String)
      begin
        @query = Item::Search::Query.from_text(q, current_user)
      rescue
        # Set the query string for error handling messages, but let the error
        # bubble up.
        @query = params[:q]
        raise
      end
    elsif q.is_a?(Hash)
      @query = Item::Search::Query.from_params(q, current_user)
    end
  end
end
