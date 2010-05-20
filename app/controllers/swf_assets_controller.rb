class SwfAssetsController < ApplicationController
  def index
    if params[:item_id]
      @swf_assets = Item.find(params[:item_id]).swf_assets.for_json.all
    elsif params[:pet_type_id]
      @swf_assets = PetType.find(params[:pet_type_id]).swf_assets.for_json.all
    end
    render :json => @swf_assets
  end
end
