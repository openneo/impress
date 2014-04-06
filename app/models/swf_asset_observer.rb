class SwfAssetObserver < ActionController::Caching::Sweeper
  def after_save(swf_asset)
    Resque.enqueue(Item::UpdateTask, swf_asset.item.id) if swf_asset.item
  end
end
