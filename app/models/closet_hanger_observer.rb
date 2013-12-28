class ClosetHangerObserver < ActionController::Caching::Sweeper
  extend FragmentExpiration

  def after_create(hanger)
    self.class.expire_item_trade_hangers(hanger) if hanger.trading?
  end

  def after_update(hanger)
    self.class.expire_item_trade_hangers(hanger) if hanger.list_id_changed?
  end

  def after_destroy(hanger)
    self.class.expire_item_trade_hangers(hanger) if hanger.trading?
  end

  def self.expire_item_trade_hangers(hanger)
    expire_fragment_in_all_locales("items/#{hanger.item_id} trade_hangers")
    expire_fragment_in_all_locales("items/#{hanger.item_id} trade_hangers owned=#{hanger.owned}")
  end
end
