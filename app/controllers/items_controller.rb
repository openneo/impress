class ItemsController < ApplicationController
  before_filter :set_query

  def index
    if params.has_key?(:q)
      begin
        if params[:per_page]
          per_page = params[:per_page].to_i
          per_page = 50 if per_page && per_page > 50
        else
          per_page = nil
        end
        @items = Item.search(@query, current_user).alphabetize.paginate :page => params[:page], :per_page => per_page
        assign_closeted!
        respond_to do |format|
          format.html { render }
          format.json { render :json => {:items => @items, :total_pages => @items.total_pages} }
          format.js { render :json => {:items => @items, :total_pages => @items.total_pages}, :callback => params[:callback] }
        end
      rescue Item::SearchError
        respond_to do |format|
          format.html { flash.now[:alert] = $!.message }
          format.json { render :json => {:error => $!.message} }
          format.js { render :json => {:error => $!.message}, :callback => params[:callback] }
        end
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.find(params[:ids])
      assign_closeted!
      respond_to do |format|
        format.json { render :json => @items }
      end
    else
      respond_to do |format|
        format.html {
          @newest_items = Item.newest.limit(18)
        }
        format.js { render :json => {:error => '$q required'}}
      end
    end
  end

  def show
    @item = Item.find params[:id]

    respond_to do |format|
      format.html do

        @trading_closet_hangers_by_owned = {
          true => @item.closet_hangers.owned_trading.newest.includes(:user),
          false => @item.closet_hangers.wanted_trading.newest.includes(:user)
        }

        if user_signed_in?
          @current_user_hangers = [true, false].map do |owned|
            hanger = current_user.closet_hangers.find_or_initialize_by_item_id_and_owned(@item.id, owned)
            hanger.quantity ||= 1
            hanger
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
    @items = @pet_type.needed_items.alphabetize
    assign_closeted!
    @pet_name = params[:name]
    render :layout => 'application'
  end

  protected

  def assign_closeted!
    current_user.assign_closeted_to_items!(@items) if user_signed_in?
  end

  def set_query
    @query = params[:q]
  end
end

