class OutfitsController < ApplicationController
  before_filter :find_authorized_outfit, :only => [:update, :destroy]
  
  def create
    if user_signed_in?
      @outfit = Outfit.new params[:outfit]
      @outfit.user = current_user
      if @outfit.save
        render :json => @outfit.id
      else
        render_outfit_errors
      end
    else
      render :json => {:errors => {:user => ['not logged in']}}, :status => :forbidden
    end
  end
  
  def for_current_user
    @outfits = user_signed_in? ? current_user.outfits : []
    render :json => @outfits
  end
  
  def destroy
    if @outfit.destroy
      render :json => true
    else
      render :json => false, :status => :bad_request
    end
  end
  
  def new
    unless fragment_exist?(:action_suffix => 'start_from_scratch_form_content')
      @colors = Color.all_ordered_by_name
      @species = Species.all_ordered_by_name
    end
    unless fragment_exist?(:action_suffix => 'top_contributors')
      @top_contributors = User.top_contributors.limit(User::PreviewTopContributorsCount)
    end
  end
  
  def show
    @outfit = Outfit.find(params[:id])
    respond_to do |format|
      format.html { render }
      format.json { render :json => @outfit }
    end
  end
  
  def update
    if @outfit.update_attributes(params[:outfit])
      render :json => true
    else
      render_outfit_errors
    end
  end
  
  private
  
  def find_authorized_outfit
    raise ActiveRecord::RecordNotFound unless user_signed_in?
    @outfit = current_user.outfits.find(params[:id])
  end
  
  def render_outfit_errors
    render :json => {:errors => @outfit.errors}, :status => :bad_request
  end
end
