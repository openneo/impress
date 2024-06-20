class Item
	module Dyeworks
		def dyeworks?
			dyeworks_base_item.present?
		end

		# Whether this is a Dyeworks item whose base item can currently be purchased
		# in the NC Mall, then dyed via Dyeworks. (Owls tracks this last part!)
		def dyeworks_buyable?
			dyeworks_base_buyable? && dyeworks_dyeable?
		end

		# Whether this is a Dyeworks item whose base item can currently be purchased
		# in the NC Mall. It may or may not currently be *dyeable* in the NC Mall,
		# because Dyeworks eligibility is often a limited-time event.
		def dyeworks_base_buyable?
			dyeworks_base_item.present? && dyeworks_base_item.currently_in_mall?
		end

		# Whether this is a Dyeworks item that can be dyed in the NC Mall ~right now,
		# either at any time or as a limited-time event. (Owls tracks this, not us!)
		def dyeworks_dyeable?
			dyeworks_permanent? || dyeworks_limited_active?
		end

		# Whether this is one of the few Dyeworks items that can be dyed in the NC
		# Mall at any time, rather than as part of a limited-time event. (Owls tracks
		# this, not us!)
		DYEWORKS_PERMANENT_PATTERN = /Permanent\s*Dyeworks/i
		def dyeworks_permanent?
			return false if nc_trade_value.nil?
			nc_trade_value.value_text.match?(DYEWORKS_PERMANENT_PATTERN)
		end

		# Whether this is a Dyeworks item that can be dyed in the NC Mall ~right
		# now, as part of a limited-time event. (Owls tracks this, not us!)
		#
		# If we aren't sure of the final date, this will still return `true`, on
		# the assumption it *is* dyeable right now and we just don't understand the
		# details of what Owls told us.
		def dyeworks_limited_active?
			return false unless dyeworks_limited?
			return true if dyeworks_limited_final_date.nil?

			# NOTE: The application is configured to NST, so this should be
			# equivalent to `Date.today`, but this is clearer and more correct imo!
			today_in_nst = Time.find_zone("Pacific Time (US & Canada)").today

			today_in_nst <= dyeworks_limited_final_date
		end

		# Whether this is a Dyeworks item that can only be dyed as part of a
		# limited-time event. (This may return true even if the end date has
		# passed, see `dyeworks_limited_active?`.) (Owls tracks this, not us!)
		DYEWORKS_LIMITED_PATTERN = /Limited\s*Dyeworks/i
		def dyeworks_limited?
			return false if nc_trade_value.nil?
			nc_trade_value.value_text.match?(DYEWORKS_LIMITED_PATTERN)
		end

		# If this is a limited-time Dyeworks item, this is the date we think the
		# event will end on. Even if `dyeworks_limited?` returns true, this could
		# still be `nil`, if we fail to parse this. (Owls tracks this, not us!)
		DYEWORKS_LIMITED_FINAL_DATE_PATTERN =
			/Dyeable\s*Thru\s*(?<month>[a-z]+)\s*(?<day>[0-9]+)/i
		def dyeworks_limited_final_date
			return nil unless dyeworks_limited?

			match = nc_trade_value.value_text.
				match(DYEWORKS_LIMITED_FINAL_DATE_PATTERN)
			return nil if match.nil?

			# Parse this "<Month> <Day>" date as the *next* such date: parse it as
			# this year at first, then add a year if it turns out to be in the past.
			#
			# NOTE: This could return strange results if the Owls date contains
			# something surprising! But the heuristic nature helps with e.g.
			# flexibility if they abbreviate months, so let's lean into `Date.parse`.
			match => {month:, day:}
			date = Date.parse("#{month} #{day}, #{Date.today.year}")
			date += 1.year if date < Date.today

			date
		end

		# The probability of getting this item when dyeing the base item.
		def dyeworks_odds
			return nil unless dyeworks?

			num_variants = dyeworks_base_item.dyeworks_variants.count
			raise "Item's Dyeworks base has *no* variants??" if num_variants < 1

			Rational(1, num_variants)
		end

		# Infer what base item this Dyeworks item probably relates to, based on
		# their names. We only use this when a new item is modeled to initialize
		# the `dyeworks_base_item` relationship in the database; after that, we
		# just use whatever the database says. (This allows manual overrides!)
		DYEWORKS_NAME_PATTERN = %r{
			^(
				# Most Dyeworks items have a colon in the name.
				Dyeworks\s+(?<color>.+?:)\s*(?<base>.+)
				|
				# But sometimes they omit it. If so, assume the first word is the color!
				Dyeworks\s+(?<color>\S+)\s*(?<base>.+)
			)$
		}x
		def inferred_dyeworks_base_item
			name_match = name.match(DYEWORKS_NAME_PATTERN)
			return nil if name_match.nil?

			Item.find_by_name(name_match["base"])
		end
	end
end