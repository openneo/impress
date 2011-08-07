require 'resque-retry'

class AssetImageConversionRequest
  extend Resque::Plugins::Retry

  @retry_limit = 5
  @retry_delay = 60

  @queue = :requested_asset_images

  def self.perform(asset_type, asset_id)
    asset = SwfAsset.where(:type => asset_type).find(asset_id)
    asset.convert_swf_if_not_converted!
  end

  class OnCreation < AssetImageConversionRequest
    @retry_limit = 5
    @retry_delay = 60

    @queue = :requested_asset_images_on_creation
  end

  class OnBrokenImageReport < AssetImageConversionRequest
    @retry_limit = 5
    @retry_delay = 60

    @queue = :reportedly_broken_asset_images
  end
end

