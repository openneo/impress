class OutfitsController < ApplicationController
  def edit
    render :layout => false
  end
  
  def new
    @colors = Color.all
    @species = Species.all
    @top_contributors = User.top_contributors.limit(3)
  end
end
