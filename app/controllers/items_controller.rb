class ItemsController < ApplicationController
  def index
    if params.has_key?(:q)
      @query = params[:q]
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
end
