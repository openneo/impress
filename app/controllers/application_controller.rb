class ApplicationController < ActionController::Base
  include FragmentLocalization
  
  protect_from_forgery

  helper_method :can_use_image_mode?, :user_is?
  
  before_filter :set_locale

  def authenticate_user! # too lazy to change references to login_path
    redirect_to(login_path) unless user_signed_in?
  end

  def authorize_user!
    raise AccessDenied unless user_signed_in? && current_user.id == params[:user_id].to_i
  end

  def can_use_image_mode?
    true
  end
  
  # This locale-inferrence method is designed for debugging. Once we're ready
  # for production, we'll probably start inferring from domain.
  def infer_locale
    inference = params[:locale]
    inference if inference && I18n.available_locales.include?(inference.to_sym)
  end
  
  def localized_fragment_exist?(key)
    localized_key = localize_fragment_key(key, locale)
    fragment_exist?(localized_key)
  end
  
  def not_found(record_name='record')
    raise ActionController::RoutingError.new("#{record_name} not found")
  end

  class AccessDenied < StandardError;end

  rescue_from AccessDenied, :with => :on_access_denied

  def on_access_denied
    render :file => 'public/403.html', :layout => false, :status => :forbidden
  end

  def redirect_back!(default=:back)
    redirect_to(params[:return_to] || default)
  end
  
  def set_locale
    I18n.locale = infer_locale || I18n.default_locale
  end

  def user_is?(user)
    user_signed_in? && user == current_user
  end
end

