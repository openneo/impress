class UsersController < ApplicationController
  before_filter :find_and_authorize_user!, :only => [:update]

  def top_contributors
    @users = User.top_contributors.paginate :page => params[:page], :per_page => 20
  end

  def update
    @user.update_attributes params[:user]
    flash[:success] = "Settings successfully saved"
    redirect_back! user_closet_hangers_path(@user)
  end

  protected

  def find_and_authorize_user!
    if current_user.id == params[:id].to_i
      @user = current_user
    else
      raise AccessDenied
    end
  end
end

