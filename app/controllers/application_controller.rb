class ApplicationController < ActionController::Base
  protect_from_forgery
  
  helper_method :current_user, :user_signed_in?
  
  protected
  
  def current_user
    unless @current_user
      @current_user = warden.authenticate
      if @current_user && !@current_user.beta?
        cookies.delete :remember_me
        warden.logout
        @current_user = nil
        flash.now[:alert] = "Only beta testers may log in right now. Sorry! We'll let you know when the new server is open to the public."
      end
    end
    @current_user
  end
  
  def user_signed_in?
    current_user ? true : false
  end
  
  def warden
    env['warden']
  end
end
