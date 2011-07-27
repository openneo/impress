class ClosetListsController < ApplicationController
  before_filter :authorize_user!

  def new
    @closet_list = current_user.closet_lists.build
  end

  def create
    @closet_list = current_user.closet_lists.build params[:closet_list]
    if @closet_list.save
      flash[:success] = "Successfully saved \"#{@closet_list.name}\""
      redirect_to user_closet_hangers_path(current_user)
    else
      flash.now[:alert] = "We can't save this list because: #{@closet_list.errors.full_messages.to_sentence}"
      render :action => :new
    end
  end
end

