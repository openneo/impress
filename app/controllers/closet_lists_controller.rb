class ClosetListsController < ApplicationController
  before_filter :authorize_user!
  before_filter :find_closet_list, :only => [:edit, :update, :destroy]

  def create
    @closet_list = current_user.closet_lists.build params[:closet_list]
    if @closet_list.save
      save_successful!
    else
      save_failed!
      render :action => :new
    end
  end

  def destroy
    @closet_list.destroy
    flash[:success] = "Successfully deleted \"#{@closet_list.name}\""
    redirect_to user_closet_hangers_path(current_user)
  end

  def new
    @closet_list = current_user.closet_lists.build params[:closet_list]
  end

  def update
    if @closet_list.update_attributes(params[:closet_list])
      save_successful!
    else
      save_failed!
      render :action => :edit
    end
  end

  protected

  def find_closet_list
    @closet_list = current_user.closet_lists.find params[:id]
  end

  def save_failed!
    flash.now[:alert] = "We can't save this list because: #{@closet_list.errors.full_messages.to_sentence}"
  end

  def save_successful!
    flash[:success] = "Successfully saved \"#{@closet_list.name}\""
    redirect_to user_closet_hangers_path(current_user)
  end
end

