class AltStylesController < ApplicationController
	def index
		@alt_styles = AltStyle.includes(:species, :color, :swf_assets).
			order(:species_id, :color_id)

		@color = find_color
		@species = find_species

		@alt_styles.merge!(@color.alt_styles) if @color
		@alt_styles.merge!(@species.alt_styles) if @species

		# We're going to link to the HTML5 image URL, so make sure we have all the
		# manifests ready!
		SwfAsset.preload_manifests @alt_styles.map(&:swf_assets).flatten

		respond_to do |format|
			format.html { render }
			format.json {
				render json: @alt_styles.includes(swf_assets: [:zone]).as_json(
					only: [:id, :species_id, :color_id, :body_id, :series_name,
								 :adjective_name, :thumbnail_url],
					include: {
						swf_assets: {
							only: [:id, :body_id],
							include: [:zone],
							methods: [:urls, :known_glitches],
						}
					},
					methods: [:series_name, :adjective_name, :thumbnail_url],
				)
			}
		end
	end

	protected

	def find_color
		if params[:color]
			Color.find_by(name: params[:color])
		end
	end

	def find_species
		if params[:species_id]
			Species.find_by(id: params[:species_id])
		elsif params[:species]
			Species.find_by(name: params[:species])
		end
	end
end
