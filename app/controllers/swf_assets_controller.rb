class SwfAssetsController < ApplicationController
  def index
    render :json => Item.find(params[:item_id]).swf_assets
  end
end
