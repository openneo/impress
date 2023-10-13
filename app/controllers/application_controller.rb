require 'ipaddr'

class ApplicationController < ActionController::Base
  include FragmentLocalization
  
  protect_from_forgery

  helper_method :current_user, :user_signed_in?
  
  before_action :set_locale

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :save_return_to_path,
    if: ->(c) { c.controller_name == 'sessions' && c.action_name == 'new' }

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

  def configure_permitted_parameters
    # Devise will automatically permit the authentication key (username) and
    # the password, but we need to let the email field through ourselves.
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email])
  end

  def save_return_to_path
    if params[:return_to]
      Rails.logger.debug "Saving return_to path: #{params[:return_to].inspect}"
      session[:devise_return_to] = params[:return_to]
    end
  end

  def after_sign_in_path_for(user)
    return_to = session.delete(:devise_return_to)
    Rails.logger.debug "Using return_to path: #{return_to.inspect}"
    return_to || root_path
  end

  def after_sign_out_path_for(user)
    return_to = params[:return_to]
    Rails.logger.debug "Using return_to path: #{return_to.inspect}"
    return_to || root_path
  end
end

