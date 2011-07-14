class ClosetHangersController < ApplicationController
  before_filter :find_item, :only => [:create, :update]

  def create
    @closet_hanger = new_hanger
    save_hanger!
  end

  def update
    begin
      @closet_hanger = @item.closet_hangers.find(params[:id])
      @closet_hanger.attributes = params[:closet_hanger]
    rescue ActiveRecord::RecordNotFound
      # Since updating a hanger is really just changing an item quantity, if
      # for some reason this hanger doesn't exist (like if user left a tab
      # open), we can still create a new hanger and do the job the user wants
      @closet_hanger = new_hanger
    end
    save_hanger!
  end

  def index
    @user = User.find params[:user_id]
    @closet_hangers = @user.closet_hangers.alphabetical_by_item_name.includes(:item)
  end

  protected

  def find_item
    @item = Item.find params[:item_id]
  end

  def new_hanger
    current_user.closet_hangers.find_or_initialize_by_item_id(@item.id, params[:closet_hanger])
  end

  def save_hanger!
    if @closet_hanger.quantity == 0
      @closet_hanger.destroy
      flash[:success] = "Success! You do not own #{@item.name}."
    elsif @closet_hanger.save
      flash[:success] = "Success! You own #{@closet_hanger.quantity} #{@item.name.pluralize}."
    else
      flash[:alert] = "We couldn't save how many of this item you own: #{@closet_hanger.errors.full_messages.to_sentence}"
    end

    redirect_to @item
  end
end

