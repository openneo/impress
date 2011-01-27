class RoulettesController < ApplicationController
  def new
    @roulette = Roulette.new
    redirect_to wardrobe_path(:anchor => @roulette.to_query)
  end
end
