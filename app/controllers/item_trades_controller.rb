class ItemTradesController < ApplicationController
	def index
		@item = Item.find params[:item_id]

		@type = type_from_params

		@item_trades = @item.closet_hangers.trading.includes(:user, :list).
			user_is_active.order('users.last_trade_activity_at DESC').to_trades

		@trades = @item_trades[@type]

		render layout: 'items'
	end

	def type_from_params
		case params[:type]
		when 'offering'
			:offering
		when 'seeking'
			:seeking
		else
			raise ArgumentError, "unexpected trades type: #{params[:type].inspect}"
		end
	end
end
