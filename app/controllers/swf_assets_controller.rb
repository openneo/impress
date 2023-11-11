class SwfAssetsController < ApplicationController
  def show
    @swf_asset = SwfAsset.find params[:id]
    render :json => @swf_asset
  end

  def links
    @swf_assets = SwfAsset.from_wardrobe_link_params(params[:asset_ids])
  end
end

