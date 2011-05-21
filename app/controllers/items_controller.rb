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
        @items = Item.search(@query).alphabetize.paginate :page => params[:page], :per_page => per_page
        respond_to do |format|
          format.html { render }
          format.json { render :json => {:items => @items, :total_pages => @items.total_pages} }
          format.js { render :json => {:items => @items, :total_pages => @items.total_pages}, :callback => params[:callback] }
        end
      rescue Item::SearchError
        respond_to do |format|
          format.html { flash.now[:alert] = $!.message }
          format.js { render :json => {:error => $!.message}, :callback => params[:callback] }
        end
      end
    elsif params.has_key?(:ids) && params[:ids].is_a?(Array)
      @items = Item.find(params[:ids])
      respond_to do |format|
        format.json { render :json => @items }
      end
    else
      respond_to do |format|
        format.html { render }
        format.js { render :json => {:error => '$q required'}}
      end
    end
  end

  def show
    @item = Item.find params[:id]
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
    @pet_name = params[:name]
    render :layout => 'application'
  end

  private

  def set_query
    @query = params[:q]
  end
end

