class PetTypesController < ApplicationController
	def show
		@pet_type = find_pet_type

		respond_to do |format|
			format.html do
				@pet_states = group_pet_states @pet_type.pet_states
			end
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

	# The `canonical` pet states are the main ones we want to show: the most
	# canonical state for each pose. The `other` pet states are, the others!
	#
	# We put *all* the UNKNOWN pet states into `other`, unless it is the only
	# pose available, in which case one will be in `canonical`.
	def group_pet_states(pet_states)
		pose_groups = pet_states.emotion_order.group_by(&:pose)
		unknowns = if pose_groups.keys != ["UNKNOWN"]
			pose_groups.delete("UNKNOWN") { [] }
		else
			[]
		end

		canonical = pose_groups.values.map(&:first).sort_by(&:pose)
		posed_others = pose_groups.values.map { |l| l.drop(1) }.flatten(1)
		other = (posed_others + unknowns).sort_by(&:pose)

		{canonical:, other:}
	end
end
