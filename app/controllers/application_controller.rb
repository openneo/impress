require 'ipaddr'

class ApplicationController < ActionController::Base
  include FragmentLocalization
  
  protect_from_forgery

  helper_method :current_user, :user_signed_in?
  
  before_action :set_locale

  def authenticate_user!
    redirect_to(new_auth_user_session_path) unless user_signed_in?
  end

  def authorize_user!
    raise AccessDenied unless user_signed_in? && current_user.id == params[:user_id].to_i
  end

  def current_user
    if auth_user_signed_in?
      User.where(remote_id: current_auth_user.id).first
    else
      nil
    end
  end

  def user_signed_in?
    auth_user_signed_in?
  end
  
  def infer_locale
    return params[:locale] if valid_locale?(params[:locale])
    return cookies[:locale] if valid_locale?(cookies[:locale])
    Rails.logger.debug "Preferred languages: #{http_accept_language.user_preferred_languages}"
    http_accept_language.language_region_compatible_from(I18n.public_locales.map(&:to_s)) ||
      I18n.default_locale
  end

  PRIVATE_IP_BLOCK = IPAddr.new('192.168.0.0/16')
  def local_only
    raise AccessDenied unless request.ip == '127.0.0.1' || PRIVATE_IP_BLOCK.include?(request.ip)
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
    render template: 'public/403.html', :layout => false, :status => :forbidden
  end

  def redirect_back!(default=:back)
    redirect_to(params[:return_to] || default)
  end
  
  def set_locale
    I18n.locale = infer_locale || I18n.default_locale
  end
  
  def valid_locale?(locale)
    locale && I18n.usable_locales.include?(locale.to_sym)
  end
end

