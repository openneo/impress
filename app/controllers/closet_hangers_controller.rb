class ClosetHangersController < ApplicationController
  before_filter :authorize_user!, :only => [:destroy, :create, :update, :update_quantities, :petpage]
  before_filter :find_item, :only => [:create, :update_quantities]
  before_filter :find_user, :only => [:index, :petpage, :update_quantities]

  def destroy
    @closet_hanger = current_user.closet_hangers.find params[:id]
    @closet_hanger.destroy
    @item = @closet_hanger.item
    closet_hanger_destroyed
  end

  def index
    @public_perspective = params.has_key?(:public) || !user_is?(@user)
    @perspective_user = current_user unless @public_perspective
    closet_lists = @user.closet_lists
    unless @perspective_user == @user
      # If we run this when the user matches, we'll end up with effectively:
      # WHERE belongs_to_user AND (is_public OR belongs_to_user)
      # and it's a bit silly to put the SQL server through a condition that's
      # always true.
      closet_lists = closet_lists.visible_to(@perspective_user)
    end
    @closet_lists_by_owned = find_closet_lists_by_owned(closet_lists)
    
    visible_groups = @user.closet_hangers_groups_visible_to(@perspective_user)
    @unlisted_closet_hangers_by_owned = find_unlisted_closet_hangers_by_owned(visible_groups)

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
    # Find all closet lists, and also the hangers of the visible closet lists
    closet_lists = @user.closet_lists.select([:id, :name, :hangers_owned]).alphabetical
    if params[:filter]
      # If user specified which lists should be visible, restrict to those
      if params[:lists] && params[:lists].respond_to?(:keys)
        visible_closet_lists = closet_lists.where(:id => params[:lists].keys)
      else
        visible_closet_lists = []
      end
    else
      # Otherwise, default to public lists
      visible_closet_lists = closet_lists.public
    end
    @closet_lists_by_owned = closet_lists.group_by(&:hangers_owned)
    @visible_closet_lists_by_owned = find_closet_lists_by_owned(visible_closet_lists)
    
    # Find which groups (own/want) should be visible
    if params[:filter]
      # If user specified which groups should be visible, restrict to those
      # (must be either true or false)
      @visible_groups = []
      if params[:groups] && params[:groups].respond_to?(:keys)
        @visible_groups << true  if params[:groups].keys.include?('true')
        @visible_groups << false if params[:groups].keys.include?('false')
      end
    else
      # Otherwise, default to public groups
      @visible_groups = @user.public_closet_hangers_groups
    end
    
    @visible_unlisted_closet_hangers_by_owned =
      find_unlisted_closet_hangers_by_owned(@visible_groups)
  end

  def create
    @closet_hanger = current_user.closet_hangers.build(params[:closet_hanger])
    @closet_hanger.item = @item
    
    if @closet_hanger.save
      closet_hanger_saved
    else
      closet_hanger_invalid
    end
  end
  
  def update
    @closet_hanger = current_user.closet_hangers.find(params[:id])
    @closet_hanger.attributes = params[:closet_hanger]
    @item = @closet_hanger.item

    unless @closet_hanger.quantity == 0 # save the hanger, new record or not
      if @closet_hanger.save
        closet_hanger_saved
      else
        closet_hanger_invalid
      end
    else # delete the hanger since the user doesn't want it
      @closet_hanger.destroy
      closet_hanger_destroyed
    end
  end
  
  def update_quantities
    begin
      ClosetHanger.transaction do
        params[:quantity].each do |key, quantity|
          ClosetHanger.set_quantity!(quantity, :user_id => @user.id,
            :item_id => @item.id, :key => key)
        end
        flash[:success] = t('closet_hangers.update_quantities.success',
                            :item_name => @item.name)
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = t('closet_hangers.update_quantities.invalid',
                        :errors => e.message)
    end
    redirect_to @item
  end

  private
  
  def closet_hanger_destroyed
    respond_to do |format|
      format.html {
        ownership_key = @closet_hanger.owned? ? 'owned' : 'wanted'
        flash[:success] = t("closet_hangers.destroy.success.#{ownership_key}",
                            :item_name => @item.name)
        redirect_back!(@item)
      }
      
      format.json { render :json => true }
    end
  end
  
  def closet_hanger_invalid
    respond_to do |format|
      format.html {
        ownership_key = @closet_hanger.owned? ? 'owned' : 'wanted'
        flash[:alert] = t("closet_hangers.create.invalid.#{ownership_key}",
                          :item_name => @item.name,
                          :errors => @closet_hanger.errors.full_messages.to_sentence)
        redirect_back!(@item)
      }
      
      format.json { render :json => {:errors => @closet_hanger.errors.full_messages}, :status => :unprocessable_entity }
    end
  end
  
  def closet_hanger_saved
    respond_to do |format|
      format.html {
        ownership_key = @closet_hanger.owned? ? 'owned' : 'wanted'
        if @closet_hanger.list
          flash[:success] = t("closet_hangers.create.success.#{ownership_key}.in_list",
                              :item_name => @item.name,
                              :list_name => @closet_hanger.list.name,
                              :count => @closet_hanger.quantity)
        else
          flash[:success] = t("closet_hangers.create.success.#{ownership_key}.unlisted",
                              :item_name => @item.name,
                              :count => @closet_hanger.quantity)
        end
        redirect_back!(@item)
      }
      
      format.json { render :json => true }
    end
  end

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

  def find_closet_lists_by_owned(closet_lists)
    return {} if closet_lists == []
    closet_lists.alphabetical.includes(:hangers => :item).
      group_by(&:hangers_owned)
  end
  
  def find_unlisted_closet_hangers_by_owned(visible_groups)
    unless visible_groups.empty?
      @user.closet_hangers.unlisted.
        owned_before_wanted.alphabetical_by_item_name.includes(:item).
        where(:owned => [visible_groups]).group_by(&:owned)
    else
      {}
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
end

