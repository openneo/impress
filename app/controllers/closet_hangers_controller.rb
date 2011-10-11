class ClosetHangersController < ApplicationController
  before_filter :authorize_user!, :only => [:destroy, :create, :update, :update_quantities, :petpage]
  before_filter :find_item, :only => [:destroy, :create, :update_quantities]
  before_filter :find_user, :only => [:index, :petpage, :update_quantities]

  def destroy
    raise ActiveRecord::RecordNotFound unless params[:closet_hanger]
    @closet_hanger = current_user.closet_hangers.find_by_item_id_and_owned!(@item.id, owned)
    @closet_hanger.destroy
    respond_to do |format|
      format.html { redirect_after_destroy! }
      format.json { render :json => true }
    end
  end

  def index
    @public_perspective = params.has_key?(:public) || !user_is?(@user)

    find_closet_hangers!

    if @public_perspective && user_signed_in?
      items = []
      @closet_lists_by_owned.each do |owned, lists|
        lists.each do |list|
          list.hangers.each { |hanger| items << hanger.item }
        end
      end

      @unlisted_closet_hangers_by_owned.each do |owned, hangers|
        hangers.each { |hanger| items << hanger.item }
      end

      current_user.assign_closeted_to_items!(items)
    end
  end

  def petpage
    @public_perspective = true
    find_closet_hangers!
  end

  def create
    @closet_hanger = current_user.closet_hangers.build(params[:closet_hanger])
    @closet_hanger.item = @item
    
    if @closet_hanger.save
      respond_to do |format|
        format.html {
          message = "Success! You #{@closet_hanger.verb(:you)} #{@closet_hanger.quantity} "
          message << ((@closet_hanger.quantity > 1) ? @item.name.pluralize : @item.name)
          message << " in the \"#{@closet_hanger.list.name}\" list" if @closet_hanger.list
          flash[:success] = "#{message}."
          redirect_back!(@item)
        }

        format.json { render :json => true }
      end
    else
      respond_to do |format|
        format.html {
          flash[:alert] = "We couldn't save how many of this item you #{@closet_hanger.verb(:you)}: #{@closet_hanger.errors.full_messages.to_sentence}"
          redirect_back!(@item)
        }

        format.json { render :json => {:errors => @closet_hanger.errors.full_messages}, :status => :unprocessable_entity }
      end
    end
  end
  
  def update
    @closet_hanger = current_user.closet_hangers.find(params[:id])
    @closet_hanger.attributes = params[:closet_hanger]
    @item = @closet_hanger.item

    unless @closet_hanger.quantity == 0 # save the hanger, new record or not
      if @closet_hanger.save
        respond_to do |format|
          format.html {
            message = "Success! You #{@closet_hanger.verb(:you)} #{@closet_hanger.quantity} "
            message << ((@closet_hanger.quantity > 1) ? @item.name.pluralize : @item.name)
            message << " in the \"#{@closet_hanger.list.name}\" list" if @closet_hanger.list
            flash[:success] = "#{message}."
            redirect_back!(@item)
          }

          format.json { render :json => true }
        end
      else
        respond_to do |format|
          format.html {
            flash[:alert] = "We couldn't save how many of this item you #{@closet_hanger.verb(:you)}: #{@closet_hanger.errors.full_messages.to_sentence}"
            redirect_back!(@item)
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
  
  def update_quantities
    begin
      ClosetHanger.transaction do
        params[:quantity].each do |key, quantity|
          ClosetHanger.set_quantity!(quantity, :user_id => @user.id,
            :item_id => @item.id, :key => key)
        end
        flash[:success] = "Successfully saved how many #{@item.name} you own and want."
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = "We couldn't save those quantities. #{e.message}"
    end
    redirect_to @item
  end

  protected

  def find_item
    @item = Item.find params[:item_id]
  end

  def find_user
    if params[:user_id]
      @user = User.find params[:user_id]
    elsif user_signed_in?
      redirect_to user_closet_hangers_path(current_user)
    else
      redirect_to login_path(:return_to => request.fullpath)
    end
  end

  def find_closet_hangers!
    @perspective_user = current_user unless @public_perspective

    @closet_lists_by_owned = @user.closet_lists.
      alphabetical.includes(:hangers => :item)
    unless @perspective_user == @user
      # If we run this when the user matches, we'll end up with effectively:
      # WHERE belongs_to_user AND (is_public OR belongs_to_user)
      # and it's a bit silly to put the SQL server through a condition that's
      # always true.
      @closet_lists_by_owned = @closet_lists_by_owned.visible_to(@perspective_user)
    end
    @closet_lists_by_owned = @closet_lists_by_owned.group_by(&:hangers_owned)

    visible_groups = @user.closet_hangers_groups_visible_to(@perspective_user)
    unless visible_groups.empty?
      @unlisted_closet_hangers_by_owned = @user.closet_hangers.unlisted.
        owned_before_wanted.alphabetical_by_item_name.includes(:item).
        where(:owned => [visible_groups]).group_by(&:owned)
    else
      @unlisted_closet_hangers_by_owned = {}
    end
  end

  def owned
    owned = true
    if params[:closet_hanger]
      owned = case params[:closet_hanger][:owned]
        when 'true', '1' then true
        when 'false', '0' then false
      end
    end
  end

  def redirect_after_destroy!
    flash[:success] = "Success! You do not #{@closet_hanger.verb(:you)} #{@item.name}."
    redirect_back!(@item)
  end
end

