class UsersController < ApplicationController
  before_action :find_and_authorize_user!, only: [:edit, :update]
  before_action :support_staff_only, only: [:edit]

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

  def edit
  end

  def update
    @user.attributes = user_params
    success = @user.save
    respond_to do |format|
      format.html {
        if success
          flash[:notice] = t('users.update.success')
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

  ALLOWED_ATTRS = [
    :owned_closet_hangers_visibility,
    :wanted_closet_hangers_visibility,
    :contact_neopets_connection_id,
  ]
  def user_params
    if support_staff?
      params.require(:user).permit(
        *ALLOWED_ATTRS, :name, :shadowbanned, :support_staff
      )
    else
      params.require(:user).permit(*ALLOWED_ATTRS)
    end
  end

  def find_and_authorize_user!
    @user = User.find(params[:id])
    raise AccessDenied unless current_user == @user || support_staff?
  end
end

