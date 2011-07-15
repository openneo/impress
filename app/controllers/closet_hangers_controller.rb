class ClosetHangersController < ApplicationController
  before_filter :authorize_user!, :only => [:set_quantity]

  def index
    @user = User.find params[:user_id]
    @closet_hangers = @user.closet_hangers.alphabetical_by_item_name.includes(:item)
  end

  # Since the user does not care about the idea of a hanger, but rather the
  # quantity of an item they own, the user would expect a create form to work
  # even after the record already exists, and an update form to work even after
  # the record is deleted. So, create and update are aliased, and both find
  # the record if it exists or create a new one if it does not.
  #
  # This is kinda a violation of REST. It's not worth breaking user
  # expectations, though, and I can't really think of a genuinely RESTful way
  # to pull this off.
  def update
    @item = Item.find params[:item_id]
    @closet_hanger = current_user.closet_hangers.find_or_initialize_by_item_id(@item.id)
    @closet_hanger.attributes = params[:closet_hanger]

    unless @closet_hanger.quantity == 0 # save the hanger, new record or not
      if @closet_hanger.save
        flash[:success] = "Success! You own #{@closet_hanger.quantity} #{@item.name.pluralize}."
      else
        flash[:alert] = "We couldn't save how many of this item you own: #{@closet_hanger.errors.full_messages.to_sentence}"
      end
    else # delete the hanger since the user doesn't want it
      @closet_hanger.destroy
      flash[:success] = "Success! You do not own #{@item.name}."
    end

    redirect_to @item
  end

  alias_method :create, :update

  protected

  def authorize_user!
    raise AccessDenied unless user_signed_in? && current_user.id == params[:user_id].to_i
  end
end

