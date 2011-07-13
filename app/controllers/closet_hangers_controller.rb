class ClosetHangersController < ApplicationController
  def index
    @user = User.find params[:user_id]
    @closet_hangers = @user.closet_hangers.alphabetical_by_item_name.includes(:item)
  end
end

