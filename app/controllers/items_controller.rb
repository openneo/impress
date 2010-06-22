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
        @results = Item.search(@query).alphabetize.paginate :page => params[:page], :per_page => per_page
        respond_to do |format|
          format.html { render }
          format.js { render :json => {:items => @results, :total_pages => @results.total_pages}, :callback => params[:callback] }
        end
      rescue
        respond_to do |format|
          format.html { flash.now[:error] = $!.message }
          format.js { render :json => {:error => $!.message}, :status => :bad_request, :callback => params[:callback] }
        end
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
