module PetTypesHelper
	def moon_progress(num, total)
		nearest_quarter = (4.0 * num / total).round / 4.0
		if nearest_quarter >= 1
			"🌕️"
		elsif nearest_quarter >= 0.75
			"🌔"
		elsif nearest_quarter >= 0.5
			"🌓"
		elsif nearest_quarter >= 0.25
			"🌒"
		else
			"🌑"
		end
	end
end
