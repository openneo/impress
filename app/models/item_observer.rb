class ItemObserver < ActionController::Caching::Sweeper
  def after_create(item)
    Rails.logger.debug "Item #{item.id} was just created"
    expire_newest_items
  end
  
  def after_update(item)
    Rails.logger.debug "Item #{item.id} was just updated"
    expire_cache_for(item)
  end

  def after_destroy(item)
    Rails.logger.debug "Item #{item.id} was just destroyed"
    expire_cache_for(item)
  end

  private
  
  def controller
    @controller ||= ActionController::Base.new
  end
  
  def expire_cache_for(item)
    controller.expire_fragment("items/#{item.id}#item_link_partial")
    controller.expire_fragment("items/#{item.id} header")
    controller.expire_fragment("items/#{item.id} info")
  end
  
  def expire_newest_items
    controller.expire_fragment('outfits#new newest_items')
    controller.expire_fragment('items#index newest_items')
  end
end
