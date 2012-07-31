class OutfitsController < ApplicationController
  before_filter :find_authorized_outfit, :only => [:update, :destroy]

  def create
    @outfit = Outfit.build_for_user(current_user, params[:outfit])
    if @outfit.save
      render :json => @outfit
    else
      render_outfit_errors
    end
  end

  def index
    if user_signed_in?
      @outfits = current_user.outfits.wardrobe_order
      respond_to do |format|
        format.html { render }
        format.json { render :json => @outfits }
      end
    else
      respond_to do |format|
        format.html { redirect_to login_path(:return_to => request.fullpath) }
        format.json { render :json => [] }
      end
    end
  end

  def destroy
    if @outfit.destroy
      respond_to do |format|
        format.html {
          flash[:success] = "Outfit #{@outfit.name} successfully deleted"
          redirect_to current_user_outfits_path
        }
        format.json { render :json => true }
      end
    else
      respond_to do |format|
        format.html {
          flash[:alert] = "Error deleting outfit. Try again?"
          redirect_to current_user_outfits_path, :status => :bad_request
        }
        format.json { render :json => false, :status => :bad_request }
      end
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
  
  def start
    @species = Species.find_by_name params[:species_name]
    @color = Color.find_by_name params[:color_name]
    if @species && @color
      redirect_to wardrobe_path(:species => @species.id, :color => @color.id)
    else
      not_found('species/color')
    end
  end

  def update
    if @outfit.update_attributes(params[:outfit])
      render :json => @outfit
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

