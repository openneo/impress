module ItemTradesHelper
	def vague_trade_timestamp(trade)
		return nil if trade.nil?

		if trade.last_activity_at >= 1.week.ago
			translate "item_trades.index.table.last_active.this_week"
		else
			trade.last_activity_at.to_date.to_fs(:month_and_year)
		end
	end

	def same_vague_trade_timestamp?(trade1, trade2)
		vague_trade_timestamp(trade1) == vague_trade_timestamp(trade2)
	end

	def sorted_vaguely_by_trade_activity(trades)
		# First, sort the list in ascending order.
		trades_ascending = trades.sort_by do |trade|
			if trade.last_activity_at >= 1.week.ago
				# Sort recent trades in a random order, but still collectively as the
				# most recent. (This discourages spamming updates to game the system!)
				[1, rand]
			else
				# Sort older trades by last trade activity.
				[0, trade.last_activity_at]
			end
		end

		# Then, reverse it!
		trades_ascending.reverse!
	end
end
