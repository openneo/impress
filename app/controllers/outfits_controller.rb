class OutfitsController < ApplicationController
  def create
    if user_signed_in?
      outfit = Outfit.new params[:outfit]
      outfit.user = current_user
      if outfit.save
        render :json => true
      else
        render :json => {:errors => outfit.errors}, :status => :bad_request
      end
    else
      render :json => {:errors => {:user => ['not logged in']}}, :status => :forbidden
    end
  end
  
  def new
    @colors = Color.all
    @species = Species.all
    @top_contributors = User.top_contributors.limit(3)
  end
end
