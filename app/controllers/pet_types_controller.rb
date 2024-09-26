class PetTypesController < ApplicationController
	def show
		@pet_type = find_pet_type

		respond_to do |format|
			format.html { render }
			format.json { render json: @pet_type }
		end
	end

	protected

	# The API-ish route uses IDs, but the human-facing route uses names.
	def find_pet_type
		if params[:species_id] && params[:color_id]
			PetType.find_by!(
				species_id: params[:species_id],
				color_id: params[:color_id],
			)
		elsif params[:name]
			color_name, species_name = params[:name].split("-", 2)
			raise ActiveRecord::RecordNotFound if species_name.blank?
			PetType.matching_name(color_name, species_name).first!
		else
			raise "expected params: species_id and color_id, or name"
		end
	end
end
