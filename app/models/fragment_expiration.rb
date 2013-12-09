module FragmentExpiration
  include FragmentLocalization
  
  delegate :expire_fragment, :to => :controller
  
  def expire_fragment_in_all_locales(key)
    I18n.usable_locales.each do |locale|
      localized_key = localize_fragment_key(key, locale)
      expire_fragment(localized_key)
    end
  end

  def expire_key_in_all_locales(key)
    I18n.usable_locales.each do |locale|
      localized_key = localize_fragment_key(key, locale)
      Rails.cache.delete(localized_key)
    end
  end
  
  private
  
  def controller
    @controller ||= ActionController::Base.new
  end
end
