class ClosetListsController < ApplicationController
  before_action :authorize_user!
  before_action :find_closet_list, :only => [:edit, :update, :destroy]

  def create
    @closet_list = current_user.closet_lists.build closet_list_params
    if @closet_list.save
      save_successful!
    else
      save_failed!
      render :action => :new
    end
  end

  def destroy
    @closet_list.destroy
    flash[:notice] = "Successfully deleted \"#{@closet_list.name}\""
    redirect_to user_closet_hangers_path(current_user)
  end

  def new
    @closet_list = current_user.closet_lists.build closet_list_params
  end

  def update
    @closet_list.attributes = closet_list_params
    if @closet_list.save
      save_successful!
    else
      save_failed!
      render :action => :edit
    end
  end

  protected

  def closet_list_params
    params.require(:closet_list).permit(
      :description, :hangers_owned, :name, :visibility)
  end

  def find_closet_list
    @closet_list = current_user.closet_lists.find params[:id]
  end

  def save_failed!
    flash.now[:alert] = "We can't save this list because: #{@closet_list.errors.full_messages.to_sentence}"
  end

  def save_successful!
    flash[:notice] = "Successfully saved \"#{@closet_list.name}\""
    redirect_to user_closet_hangers_path(current_user)
  end
end

