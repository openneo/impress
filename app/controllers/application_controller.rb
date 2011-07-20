class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :can_use_image_mode?, :user_is?

  def authenticate_user! # too lazy to change references to login_path
    redirect_to(login_path) unless user_signed_in?
  end

  def can_use_image_mode?
    user_signed_in? && current_user.image_mode_tester?
  end

  class AccessDenied < StandardError;end

  rescue_from AccessDenied, :with => :on_access_denied

  def on_access_denied
    render :file => 'public/403.html', :layout => false, :status => :forbidden
  end

  def redirect_back!(default=:back)
    redirect_to(params[:return_to] || default)
  end

  def user_is?(user)
    user_signed_in? && user == current_user
  end
end

