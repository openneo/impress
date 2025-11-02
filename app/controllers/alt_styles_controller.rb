class AltStylesController < ApplicationController
	before_action :support_staff_only, except: [:index]

	def index
		@all_series_names = AltStyle.all_series_names
		@all_color_names = AltStyle.all_supported_colors.map(&:human_name).sort
		@all_species_names = AltStyle.all_supported_species.map(&:human_name).sort

		@series_name = params[:series]
		@color = find_color
		@species = find_species

		@alt_styles = AltStyle.includes(:color, :species, :swf_assets)
		@alt_styles.where!(series_name: @series_name) if @series_name.present?
		@alt_styles.merge!(@color.alt_styles) if @color
		@alt_styles.merge!(@species.alt_styles) if @species

		respond_to do |format|
			format.html {
				@alt_styles = @alt_styles.
					by_creation_date.order(:color_id, :species_id, :series_name).
					paginate(page: params[:page], per_page: 30)

				# We're using the HTML5 image for our preview, so make sure we have all the
				# manifests ready!
				SwfAsset.preload_manifests @alt_styles.map(&:swf_assets).flatten

				if support_staff?
					@counts = {
						total: AltStyle.count,
						unlabeled: AltStyle.unlabeled.count,
					}
					@counts[:labeled] = @counts[:total] - @counts[:unlabeled]
					@unlabeled_style = AltStyle.unlabeled.newest.first
				end

				render
			}
			format.json {
				@alt_styles = @alt_styles.includes(swf_assets: [:zone]).by_name_grouped
				render json: @alt_styles.as_json(
					only: [:id, :species_id, :color_id, :body_id, :thumbnail_url],
					include: {
						swf_assets: {
							only: [:id, :body_id],
							include: [:zone],
							methods: [:urls, :known_glitches],
						}
					},
					methods: [:series_main_name, :adjective_name],
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
			redirect_to destination_after_save
		else
			render action: :edit, status: :bad_request
		end
	end

	protected

	def alt_style_params
		params.require(:alt_style).
			permit(:real_series_name, :real_full_name, :thumbnail_url)
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

	def destination_after_save
		if params[:next] == "unlabeled-style"
			next_unlabeled_style_path
		else
			alt_styles_path
		end
	end

	def next_unlabeled_style_path
		unlabeled_style = AltStyle.unlabeled.newest.first
		if unlabeled_style
			edit_alt_style_path(unlabeled_style, next: "unlabeled-style")
		else
			alt_styles_path
		end
	end
end
