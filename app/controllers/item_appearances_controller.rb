class ItemAppearancesController < ApplicationController
	def index
		@item = Item.find(params[:item_id])
		render json: @item.as_json(
			only: [:id], methods: [:appearances, :restricted_zones]
		)
	end
end
