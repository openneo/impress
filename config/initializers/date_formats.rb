Date::DATE_FORMATS[:month_and_day] = "%B %e"
Time::DATE_FORMATS[:long_nst] = lambda { |time|
	time.in_time_zone("Pacific Time (US & Canada)").
		to_formatted_s(:long) + " NST"
}
