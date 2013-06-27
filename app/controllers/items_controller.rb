class ItemsController < ApplicationController
  before_filter :set_query
  rescue_from Item::Search::Error, :with => :search_error

  def index
    if params.has_key?(:q)
      begin
        if params[:per_page]
          per_page = params[:per_page].to_i
          per_page = 50 if per_page && per_page > 50
        else
          per_page = 30
        end
        # Note that we sort by name by hand, since we might have to use
        # fallbacks after the fact
        # TODO: use proxies for everything!
        output_format = params[:format] == :html ? :records : :proxies
        @items = Item::Search::Query.from_text(@query, current_user).
          paginate(page: params[:page], per_page: per_page, as: output_format)
        assign_closeted!
        respond_to do |format|
          format.html { render }
          format.json {
            @items.prepare_method(:as_json)
            render json: {items: @items, total_pages: @items.total_pages}
          }
          format.js {
            @items.prepare_method(:as_json)
            render json: {items: @items, total_pages: @items.total_pages},
                   callback: params[:callback]
          }
        end
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.includes(:translations).find(params[:ids])
      assign_closeted!
      respond_to do |format|
        format.json { render json: @items }
      end
    else
      respond_to do |format|
        format.html {
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
    @query = params[:q]
  end
end

