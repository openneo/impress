class ItemsController < ApplicationController
  before_action :set_query
  rescue_from Item::Search::Error, :with => :search_error

  def index
    if @query
      if params[:per_page]
        per_page = params[:per_page].to_i
        per_page = 50 if per_page && per_page > 50
      else
        per_page = 30
      end

      @items = @query.results.paginate(
        page: params[:page], per_page: per_page)
      assign_closeted!(@items)

      respond_to do |format|
        format.html {
          @campaign = Fundraising::Campaign.current rescue nil
          if @items.count == 1
            redirect_to @items.first
          else
            render
          end
        }
        format.json {
          render json: {
            items: @items.as_json(
              methods: [:nc?, :pb?, :owned?, :wanted?],
            ),
            appearances: load_appearances.as_json(
              include: {
                swf_assets: {
                  only: [:id, :remote_id, :body_id],
                  include: {
                    zone: {
                      only: [:id, :depth, :label],
                      methods: [:is_commonly_used_by_items],
                    },
                    restricted_zones: {
                      only: [:id, :depth, :label],
                      methods: [:is_commonly_used_by_items],
                    },
                  },
                  methods: [:urls, :known_glitches],
                },
              }
            ),
            total_pages: @items.total_pages,
            query: @query.to_s,
          }
        }
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.find(params[:ids])
      assign_closeted!(@items)
      respond_to do |format|
        format.json { render json: @items }
      end
    else
      respond_to do |format|
        format.html {
          @campaign = Fundraising::Campaign.current rescue nil
          @newest_items = Item.newest.limit(18)
        }
      end
    end
  end

  def show
    @item = Item.find params[:id]

    respond_to do |format|
      format.html do
        @trades = @item.closet_hangers.trading.user_is_active.to_trades

        @contributors_with_counts = @item.contributors_with_counts

        if user_signed_in?
          @current_user_lists = current_user.closet_lists.alphabetical.
            group_by_owned
          @current_user_quantities = current_user.item_quantities_for(@item)
        end

        @preview_pet_type = PetType.find_by_color_id_and_species_id(
          Color.find_by_name("Blue"),
          Species.find_by_name("Acara"),
        )
        @item_layers = @item.appearance_for(
          @preview_pet_type, swf_asset_includes: [:zone]
        ).swf_assets
        @pet_layers = @preview_pet_type.canonical_pet_state.swf_assets.
          includes(:zone)
      end

      format.gif do
        expires_in 1.month
        redirect_to @item.thumbnail_url, allow_other_host: true
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
    
    @items = @pet_type.needed_items.order(:name)
    assign_closeted!(@items)
    
    respond_to do |format|
      format.html { @pet_name = params[:name] ; render :layout => 'application' }
      format.json { render :json => @items }
    end
  end

  def sources
    # Load all the items, then group them by source.
    item_ids = params[:ids].split(",")
    @all_items = Item.where(id: item_ids).includes(:nc_mall_record).
      includes(:dyeworks_base_item).order(:name).limit(50)
    @items = @all_items.group_by(&:source).tap { |i| i.default = [] }

    assign_closeted!(@all_items)

    if @all_items.empty?
      render file: "public/404.html", status: :not_found, layout: nil
      return
    end

    # For Dyeworks items whose base is currently in the NC Mall, preload their
    # trade values. We'll use this to determine which ones are fully buyable rn
    # (because Owls tracks this data and we don't).
    Item.preload_nc_trade_values(@items[:dyeworks])

    # Start loading the NC trade values for the non-Mall NC items.
    trade_values_task = Async { Item.preload_nc_trade_values(@items[:other_nc]) }

    # Also, PB items have some special handling: we group them by color, then
    # load example pet types for the colors that don't have paint brushes.
    @pb_items_by_color = @items[:pb].group_by(&:pb_color).
      sort_by { |color, items| color&.name }.to_h

    colors_without_thumbnails = @pb_items_by_color.keys.
      select(&:present?).reject(&:pb_item_thumbnail_url?)

    @pb_color_pet_types = colors_without_thumbnails.map do |color|
      # Infer the ideal species from the first item we can, then try to find a
      # matching pet type to use as the thumbnail, if needed.
      species = @pb_items_by_color[color].map(&:pb_species).select(&:present?)
        .first
      [color, color.example_pet_type(preferred_species: species)]
    end.to_h

    # Create a second value that only include the items the user *needs*: that
    # is, that they don't already own.
    @items_needed = @items.transform_values { |items| items.reject(&:owned?) }
    @pb_items_needed_by_color =
      @pb_items_by_color.transform_values { |items| items.reject(&:owned?) }

    # Finish loading the NC trade values.
    trade_values_task.wait

    render layout: "application"
  end

  protected

  def assign_closeted!(items)
    current_user.assign_closeted_to_items!(items) if user_signed_in?
  end

  def load_appearances
    appearance_params = params[:with_appearances_for]
    return {} if appearance_params.blank?
    
    if appearance_params[:alt_style_id].present?
      target = Item::Search::Query.load_alt_style_by_id(
        appearance_params[:alt_style_id])
    else
      target = Item::Search::Query.load_pet_type_by_color_and_species(
        appearance_params[:color_id], appearance_params[:species_id])
    end

    target.appearances_for(@items.map(&:id), swf_asset_includes: [:zone]).
      tap do |appearances|
        # Preload the manifests for these SWF assets concurrently, rather than
        # loading them in sequence when we generate the JSON.
        swf_assets = appearances.values.map(&:swf_assets).flatten
        SwfAsset.preload_manifests(swf_assets)
      end
  end
  
  def search_error(e)
    @items = []
    @query = params[:q]
    respond_to do |format|
      format.html { flash.now[:alert] = e.message; render }
      format.json { render :json => {error: e.message} }
    end
  end

  def set_query
    q = params[:q]
    if q.is_a?(String)
      @query = Item::Search::Query.from_text(q, current_user)
    elsif q.is_a?(ActionController::Parameters)
      @query = Item::Search::Query.from_params(q, current_user)
    end
  end
end
