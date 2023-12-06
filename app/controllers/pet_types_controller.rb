class PetTypesController < ApplicationController
	def index
		color = Color.find params[:color_id]
		pet_types = color.pet_types.includes(pet_states: [:swf_assets]).
			includes(species: [:translations])

		# This is a relatively big request, for relatively static data. Let's
		# consider it fresh for 10min (so new pet releases show up quickly), but
		# it's also okay for the client to quickly serve the cached copy then
		# reload in the background, if it's been less than a day.
		expires_in 10.minutes, stale_while_revalidate: 1.day, public: true

		# We dive deep to get all the right fields for appearance data, cuz this
		# endpoint is primarily used to power the preview on the item page!
		render json: pet_types.map { |pt|
			pt.as_json(
				only: [:id, :body_id],
				include: {
					species: {only: [:id], methods: [:name, :human_name]},
					canonical_pet_state: {
						only: [:id],
						methods: [:pose],
						include: {
							swf_assets: {
								only: [:id, :known_glitches],
      					methods: [:zone, :restricted_zones, :urls],
							},
						},
					},
				},
			)
		}
	end

	def show
		@pet_type = PetType.
			where(species_id: params[:species_id]).
			where(color_id: params[:color_id]).
			first

		render json: @pet_type
	end
end
