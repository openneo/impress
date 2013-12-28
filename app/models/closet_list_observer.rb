class ClosetListObserver < ActionController::Caching::Sweeper
  include FragmentExpiration

  def after_update(list)
    expire_all_items_trade_hangers(list) if list.trading_changed?
  end

  def before_destroy(list)
    # Nullify all the child records explicitly, which will in turn trigger
    # their update callbacks and expire their items' caches. This occurs in the
    # same transaction as the list's destruction.
    list.hangers.each { |h| h.list_id = nil; h.save! }
  end

  def expire_all_items_trade_hangers(list)
    list.hangers.each { |h| ClosetHangerObserver.expire_item_trade_hangers(h) }
  end
end