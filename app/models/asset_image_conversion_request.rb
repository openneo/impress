class AssetImageConversionRequest
  @queue = :requested_asset_images

  def self.perform(asset_type, asset_id)
    asset = SwfAsset.where(:type => asset_type).find(asset_id)
    asset.convert_swf_if_not_converted!
  end

  class OnCreation < AssetImageConversionRequest
    @queue = :requested_asset_images_on_creation
  end
end

