class AssetImageConversionRequestsController < ApplicationController
  def create
    @swf_asset = SwfAsset.find params[:swf_asset_id]
    @swf_asset.request_image_conversion!
    render :nothing => true
  end
end

