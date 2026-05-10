class Admin::NeologinCookiesController < ApplicationController
  before_action :authenticate_user!
  before_action :support_staff_only

  def index
    @current_cookie = NeologinCookie.current
    @history = NeologinCookie.recent_first.includes(:created_by).limit(20)
    @new_cookie = NeologinCookie.new
  end

  def create
    @new_cookie = NeologinCookie.new(cookie_params)
    @new_cookie.created_by = current_user

    if @new_cookie.save
      redirect_to admin_neologin_cookies_path,
        notice: "Saved new Neologin cookie. The next import run will use it."
    else
      @current_cookie = NeologinCookie.current
      @history = NeologinCookie.recent_first.includes(:created_by).limit(20)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def cookie_params
    params.require(:neologin_cookie).permit(:cookie).tap do |p|
      p[:cookie] = p[:cookie].to_s.strip.delete_prefix("neologin=")
    end
  end
end
