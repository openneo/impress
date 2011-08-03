class NeopetsUsersController < ApplicationController
  before_filter :authenticate_user!, :build_neopets_user

  rescue_from NeopetsUser::NotFound, :with => :not_found

  def new
    @neopets_user.username = current_user.neopets_username
  end

  def create
    @neopets_user.username = params[:neopets_user][:username]
    @neopets_user.load!
    @neopets_user.save_hangers!

    message = "Success! We loaded user \"#{@neopets_user.username}\""
    unless @neopets_user.hangers.empty?
      message << " and added #{@neopets_user.hangers.size} items."
    else
      message << ", but already had all of this data recorded."
    end

    flash[:success] = message
    redirect_to user_closet_hangers_path(current_user)
  end

  protected

  def build_neopets_user
    @neopets_user = NeopetsUser.new current_user
  end

  def not_found
    flash.now[:alert] = "Could not find user \"#{@neopets_user.username}\". Did you spell it correctly?"
    render :action => :new
  end
end

