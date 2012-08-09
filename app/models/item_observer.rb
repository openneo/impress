class ItemObserver < ActionController::Caching::Sweeper
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
    ActionController::Base.new.expire_fragment("items/#{item.id}#item_link_partial")
  end
end
