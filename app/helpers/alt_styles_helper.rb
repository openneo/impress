module AltStylesHelper
	def view_or_edit_alt_style_url(alt_style)
		if support_staff?
			edit_alt_style_path alt_style
		else
			wardrobe_path(
				species: alt_style.species_id,
				color: alt_style.color_id,
				style: alt_style.id,
			)
		end
	end
end
