class ItemObserver < ActionController::Caching::Sweeper
  include FragmentExpiration
  
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
  
  def expire_cache_for(item)
    expire_fragment("items/#{item.id}#item_link_partial")
    expire_fragment("items/#{item.id} header")
    expire_fragment("items/#{item.id} info")
  end
  
  def expire_newest_items
    expire_fragment_in_all_locales('outfits#new newest_items')
    expire_fragment_in_all_locales('items#index newest_items')
  end
end
