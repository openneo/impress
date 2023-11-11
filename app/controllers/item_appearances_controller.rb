class ItemAppearancesController < ApplicationController
	def index
		@item = Item.find(params[:item_id])
		render json: @item.appearances
	end
end
