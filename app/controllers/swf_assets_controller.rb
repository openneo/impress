class SwfAssetsController < ApplicationController
  caches_page :index
  
  def index
    if params[:item_id]
      @swf_assets = Item.find(params[:item_id]).swf_assets
      if params[:body_id]
        @swf_assets = @swf_assets.fitting_body_id(params[:body_id])
      else
        @swf_assets = @swf_assets.fitting_standard_body_ids
        json = @swf_assets.all.group_by(&:body_id)
      end
    elsif params[:pet_type_id]
      @swf_assets = PetType.find(params[:pet_type_id]).pet_states.first.swf_assets
    end
    json ||= @swf_assets.all
    render :json => json
  end
end
