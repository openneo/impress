puts 'Hey! Item sweeper!'

class ItemSweeper < ActionController::Caching::Sweeper
  observe Item

  def after_update(item)
    expire_cache_for(item)
  end

  def after_destroy(item)
    expire_cache_for(item)
  end

  private
  def expire_cache_for(item)
    options = {:controller => 'items', :action => 'show', :id => item.id}
    expire_action(options)
  end
  
  def expire_action(options)
    if @controller
      super
    elsif LocalImpressHost
      @tmp_controller ||= SweeperController.new
      @tmp_controller.expire_action_proxy(options.dup)
    end
  end
end
