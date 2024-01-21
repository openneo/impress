module ItemTradesHelper
	def vague_trade_timestamp(last_trade_activity_at)
		if last_trade_activity_at >= 1.week.ago
			translate "item_trades.index.table.last_active.this_week"
		else
			last_trade_activity_at.strftime("%b %Y")
		end
	end

	def sorted_vaguely_by_trade_activity(trades)
		# First, sort the list in ascending order.
		trades_ascending = trades.sort_by do |trade|
			if trade.user.last_trade_activity_at >= 1.week.ago
				# Sort recent trades in a random order, but still collectively as the
				# most recent. (This discourages spamming updates to game the system!)
				[1, rand]
			else
				# Sort older trades by last trade activity.
				[0, trade.user.last_trade_activity_at]
			end
		end

		# Then, reverse it!
		trades_ascending.reverse!
	end
end
