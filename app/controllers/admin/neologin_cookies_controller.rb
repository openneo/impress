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

    begin
      Neologin.test!(@new_cookie.cookie)
    rescue Neologin::CookieRejected
      @new_cookie.errors.add(:cookie, "was rejected by Neopets — is this the right value?")
    rescue => e
      @new_cookie.errors.add(:base, "Test request failed: #{e.message.to_s.truncate(200)}")
    end

    if @new_cookie.errors.empty? && @new_cookie.save
      @new_cookie.record_success!
      DiscordNotifier.notify_neologin_refreshed(@new_cookie)
      redirect_to admin_neologin_cookies_path,
        notice: "Cookie tested and saved — it's working!"
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
