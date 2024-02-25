class ItemsController < ApplicationController
  before_action :set_query
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

        @items = @query.results.paginate(
          page: params[:page], per_page: per_page)
        assign_closeted!

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
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.find(params[:ids])
      assign_closeted!
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
    
    @items = @pet_type.needed_items.order(:name)
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

  def load_appearances
    appearance_params = params[:with_appearances_for]
    return {} if appearance_params.blank?

    pet_type = Item::Search::Query.load_pet_type_by_color_and_species(
      appearance_params[:color_id], appearance_params[:species_id])
    pet_type.appearances_for(@items.map(&:id), swf_asset_includes: [:zone])
  end
  
  def search_error(e)
    @items = []
    respond_to do |format|
      format.html { flash.now[:alert] = e.message; render }
      format.json { render :json => {error: e.message} }
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
    elsif q.is_a?(ActionController::Parameters)
      @query = Item::Search::Query.from_params(q, current_user)
    end
  end
end
