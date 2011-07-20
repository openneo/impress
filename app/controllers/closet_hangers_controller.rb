class ClosetHangersController < ApplicationController
  before_filter :authorize_user!, :only => [:destroy, :create, :update]
  before_filter :find_item, :only => [:destroy, :create, :update]

  def destroy
    @closet_hanger = current_user.closet_hangers.find_by_item_id!(@item.id)
    @closet_hanger.destroy
    respond_to do |format|
      format.html { redirect_after_destroy! }
      format.json { render :json => true }
    end
  end

  def index
    @user = User.find params[:user_id]
    @closet_hangers = @user.closet_hangers.alphabetical_by_item_name.includes(:item)
    @public_perspective = params.has_key?(:public) || !user_is?(@user)
  end

  # Since the user does not care about the idea of a hanger, but rather the
  # quantity of an item they own, the user would expect a create form to work
  # even after the record already exists, and an update form to work even after
  # the record is deleted. So, create and update are aliased, and both find
  # the record if it exists or create a new one if it does not. They will even
  # delete the record if quantity is zero.
  #
  # This is kinda a violation of REST. It's not worth breaking user
  # expectations, though, and I can't really think of a genuinely RESTful way
  # to pull this off.
  def update
    @closet_hanger = current_user.closet_hangers.find_or_initialize_by_item_id(@item.id)
    @closet_hanger.attributes = params[:closet_hanger]

    unless @closet_hanger.quantity == 0 # save the hanger, new record or not
      if @closet_hanger.save
        respond_to do |format|
          format.html {
            flash[:success] = "Success! You own #{@closet_hanger.quantity} #{@item.name.pluralize}."
            redirect_back!
          }

          format.json { render :json => true }
        end
      else
        respond_to do |format|
          format.html {
            flash[:alert] = "We couldn't save how many of this item you own: #{@closet_hanger.errors.full_messages.to_sentence}"
            redirect_back!
          }

          format.json { render :json => {:errors => @closet_hanger.errors.full_messages}, :status => :unprocessable_entity }
        end
      end
    else # delete the hanger since the user doesn't want it
      @closet_hanger.destroy
      respond_to do |format|
        format.html { redirect_after_destroy! }

        format.json { render :json => true }
      end
    end
  end

  alias_method :create, :update

  protected

  def authorize_user!
    raise AccessDenied unless user_signed_in? && current_user.id == params[:user_id].to_i
  end

  def find_item
    @item = Item.find params[:item_id]
  end

  def redirect_after_destroy!
    flash[:success] = "Success! You do not own #{@item.name}."
    redirect_back!
  end

  def redirect_back!
    redirect_to params[:return_to] || @item
  end
end

