class OutfitsController < ApplicationController
  before_filter :find_outfit, :only => [:show, :update, :destroy]
  
  def create
    if user_signed_in?
      outfit = Outfit.new params[:outfit]
      outfit.user = current_user
      if outfit.save
        render :json => outfit.id
      else
        render :json => {:errors => outfit.errors}, :status => :bad_request
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
    authenticate_action &:destroy
  end
  
  def new
    @colors = Color.all
    @species = Species.all
    @top_contributors = User.top_contributors.limit(3)
  end
  
  def show
    render :json => @outfit
  end
  
  def update
    authenticate_action { |outfit| outfit.update_attributes(params[:outfit]) }
  end
  
  private
  
  def authenticate_action
    if yield(@outfit)
      render :json => true
    else
      render :json => false, :status => :bad_request
    end
  end
  
  def find_outfit
    raise ActiveRecord::RecordNotFound unless user_signed_in?
    @outfit = current_user.outfits.find(params[:id])
  end
end
