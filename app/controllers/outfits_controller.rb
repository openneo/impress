class OutfitsController < ApplicationController
  def new
    @colors = Color.all
    @species = Species.all
    @top_contributors = User.top_contributors.limit(3)
  end
end
