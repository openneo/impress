class AltStylesController < ApplicationController
	def index
		@alt_styles = AltStyle.includes(:species, :color, :swf_assets).
			order(:species_id, :color_id).all
	end
end
