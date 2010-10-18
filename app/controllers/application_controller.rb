class ApplicationController < ActionController::Base
  protect_from_forgery
  
  helper_method :current_user, :user_signed_in?
  
  protected
  
  def current_user
    @current_user ||= warden.authenticate
  end
  
  def user_signed_in?
    current_user ? true : false
  end
  
  def warden
    env['warden']
  end
end
