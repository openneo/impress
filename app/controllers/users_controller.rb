class UsersController < ApplicationController
  before_filter :find_and_authorize_user!, :only => [:update]

  def top_contributors
    @users = User.top_contributors.paginate :page => params[:page], :per_page => 20
  end

  def update
    success = @user.update_attributes params[:user]
    respond_to do |format|
      format.html {
        if success
          flash[:success] = "Settings successfully saved"
          redirect_back! user_closet_hangers_path(@user)
        else
          flash[:alert] = "Error saving user settings: #{@user.errors.full_messages.to_sentence}"
        end
      }

      format.json {
        if success
          render :json => true
        else
          render :json => {:errors => @user.errors.full_messages}, :status => :unprocessable_entity
        end
      }
    end
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

