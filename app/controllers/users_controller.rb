class UsersController < ApplicationController
  before_filter :find_and_authorize_user!, :only => [:update]

  def index # search, really
    name = params[:name]
    @user = User.find_by_name(name)
    if @user
      redirect_to user_closet_hangers_path(@user)
    else
      flash[:alert] = t('users.index.not_found', :name => name)
      redirect_to root_path
    end
  end

  def top_contributors
    @users = User.top_contributors.paginate :page => params[:page], :per_page => 20
  end

  def update
    success = @user.update_attributes params[:user]
    respond_to do |format|
      format.html {
        if success
          flash[:success] = t('users.update.success')
          redirect_back! user_closet_hangers_path(@user)
        else
          flash[:alert] = t('users.update.invalid',
                            :errors => @user.errors.full_messages.to_sentence)
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

