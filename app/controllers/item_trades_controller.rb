class ItemTradesController < ApplicationController
	def index
		@item = Item.find params[:item_id]
		@type = type_from_params

		@item_trades = @item.closet_hangers.trading.includes(:user, :list).
			user_is_active.order('users.last_trade_activity_at DESC').
			to_trades(current_user, request.remote_ip)
		@trades = @item_trades[@type]

		if user_signed_in?
			@current_user_lists = current_user.closet_lists.alphabetical.
				group_by_owned
			@current_user_quantities = current_user.item_quantities_for(@item)
		end

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
