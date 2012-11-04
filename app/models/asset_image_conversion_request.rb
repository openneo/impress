require 'resque-retry'
require 'timeout'

class AssetImageConversionRequest
  TIMEOUT_IN_SECONDS = 30
  
  extend Resque::Plugins::Retry

  @retry_limit = 5
  @retry_delay = 60

  @queue = :requested_asset_images

  def self.perform(asset_id)
    Timeout::timeout(TIMEOUT_IN_SECONDS) do
      asset = SwfAsset.find(asset_id)
      asset.convert_swf_if_not_converted!
    end
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

