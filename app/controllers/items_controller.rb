class ItemsController < ApplicationController
  before_filter :set_query
  
  def index
    if params.has_key?(:q)
      begin
        @results = Item.search(@query).alphabetize.paginate :page => params[:page]
      rescue
        flash.now[:alert] = $!.message
      end
    end
  end
  
  def show
    @item = Item.find params[:id]
  end
  
  private
  
  def set_query
    @query = params[:q]
  end
end
