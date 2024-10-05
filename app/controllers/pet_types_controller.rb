class PetTypesController < ApplicationController
	def index
		@species_names = Species.order(:name).map(&:human_name)
		@color_names = Color.order(:name).map(&:human_name)

		if params[:species].present?
			@selected_species = Species.find_by!(name: params[:species])
			@selected_species_name = @selected_species.human_name
		end
		if params[:color].present?
			@selected_color = Color.find_by!(name: params[:color])
			@selected_color_name = @selected_color.human_name
		end

		@pet_types = PetType.
			includes(:color, :species, :pet_states).
			order(created_at: :desc).
			paginate(page: params[:page], per_page: 30)

		if @selected_species
			@pet_types = @pet_types.where(species_id: @selected_species)
		end
		if @selected_color
			@pet_types = @pet_types.where(color_id: @selected_color)
		end
	end

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
			color_name, _, species_name = params[:name].rpartition("-")
			raise ActiveRecord::RecordNotFound if species_name.blank?
			PetType.matching_name(color_name, species_name).first!
		else
			raise "expected params: species_id and color_id, or name"
		end
	end

	# The `canonical` pet states are the main ones we want to show: the most
	# canonical state for each pose. The `other` pet states are, the others!
	#
	# If no main poses are available, then we just make all the poses
	# "canonical", and show the whole mish-mash!
	def group_pet_states(pet_states)
		pose_groups = pet_states.emotion_order.group_by(&:pose)
		main_groups =
			pose_groups.select { |k| PetState::MAIN_POSES.include?(k) }.values
		other_groups =
			pose_groups.reject { |k| PetState::MAIN_POSES.include?(k) }.values

		if main_groups.empty?
			return {canonical: other_groups.flatten(1).sort_by(&:pose), other: []}
		end

		canonical = main_groups.map(&:first).sort_by(&:pose)
		main_others = main_groups.map { |l| l.drop(1) }.flatten(1)
		other = (main_others + other_groups.flatten(1)).sort_by(&:pose)

		{canonical:, other:}
	end
end
