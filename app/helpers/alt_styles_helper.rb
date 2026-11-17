module AltStylesHelper
	def view_or_edit_alt_style_url(alt_style)
		if support_staff?
			edit_alt_style_path alt_style
		else
			style_token_wardrobe_path alt_style
		end
	end
end
