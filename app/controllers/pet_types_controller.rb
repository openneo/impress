class PetTypesController < ApplicationController
	def show
		@pet_type = PetType.
			where(species_id: params[:species_id]).
			where(color_id: params[:color_id]).
			first

		render json: @pet_type
	end
end
