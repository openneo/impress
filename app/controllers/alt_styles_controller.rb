class AltStylesController < ApplicationController
	def index
		@alt_styles = AltStyle.includes(:species, :color, :swf_assets).
			order(:species_id, :color_id)

		if params[:species_id]
			@species = Species.find(params[:species_id])
			@alt_styles = @alt_styles.merge(@species.alt_styles)
		end

		respond_to do |format|
			format.html { render }
			format.json {
				render json: @alt_styles.includes(swf_assets: [:zone]).as_json(
					include: {swf_assets: {include: [:zone], methods: [:image_url]}},
					methods: [:series_name, :adjective_name, :thumbnail_url],
				)
			}
		end
	end
end
