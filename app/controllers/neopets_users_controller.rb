class NeopetsUsersController < ApplicationController
  before_action :authenticate_user!, :build_neopets_user

  rescue_from NeopetsUser::NotFound, :with => :not_found

  def new
    @neopets_user.username = current_user.contact_neopets_username
  end

  def create
    @neopets_user.username = params[:neopets_user][:username]
    @neopets_user.list_id = params[:neopets_user][:list_id]
    @neopets_user.load!
    @neopets_user.save_hangers!

    flash[:success] = t('neopets_users.create.success',
                        :user_name => @neopets_user.username,
                        :count => @neopets_user.hangers.size)
    redirect_to user_closet_hangers_path(current_user)
  end

  protected

  def build_neopets_user
    @neopets_user = NeopetsUser.new current_user
  end

  def not_found
    flash.now[:alert] = t('neopets_users.create.not_found',
                          :user_name => @neopets_user.username)
    render :action => :new
  end
end

