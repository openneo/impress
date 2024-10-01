class AltStylesController < ApplicationController
	before_action :support_staff_only, except: [:index]

	def index
		@all_alt_styles = AltStyle.includes(:species, :color).
			order(:species_id, :color_id)

		@all_colors = @all_alt_styles.map(&:color).uniq.sort_by(&:name)
		@all_species = @all_alt_styles.map(&:species).uniq.sort_by(&:name)

		@all_color_names = @all_colors.map(&:human_name)
		@all_species_names = @all_species.map(&:human_name)

		@color = find_color
		@species = find_species

		@alt_styles = @all_alt_styles.includes(:swf_assets)
		@alt_styles.merge!(@color.alt_styles) if @color
		@alt_styles.merge!(@species.alt_styles) if @species

		# We're using the HTML5 image for our preview, so make sure we have all the
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

	def edit
		@alt_style = AltStyle.find params[:id]
	end

	def update
		@alt_style = AltStyle.find params[:id]

		if @alt_style.update(alt_style_params)
			flash[:notice] = "\"#{@alt_style.full_name}\" successfully saved!"
			redirect_to alt_styles_path
		else
			render action: :edit, status: :bad_request
		end
	end

	protected

	def alt_style_params
		params.require(:alt_style).permit(:series_name, :thumbnail_url)
	end

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
