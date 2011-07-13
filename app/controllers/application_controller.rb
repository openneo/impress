class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :can_use_image_mode?

  def authenticate_user! # too lazy to change references to login_path
    redirect_to(login_path) unless user_signed_in?
  end

  def can_use_image_mode?
    user_signed_in? && current_user.image_mode_tester?
  end
end

