class PetStatesController < ApplicationController
	before_action :find_pet_state
	before_action :support_staff_only

	def edit
	end

	def update
		if @pet_state.update(pet_state_params)
			flash[:notice] = "Pet appearance \##{@pet_state.id} successfully saved!"
			redirect_to destination_after_save
		else
			render action: :edit, status: :bad_request
		end
	end

	protected

	def find_pet_state
		@pet_type = PetType.find_by_param!(params[:pet_type_name])
		@pet_state = @pet_type.pet_states.find(params[:id])
		@reference_pet_type = @pet_type.reference
	end

	def pet_state_params
		params.require(:pet_state).permit(:pose, :glitched)
	end

	def destination_after_save
		if params[:next] == "unlabeled-appearance"
			next_unlabeled_appearance_path
		else
			@pet_type
		end
	end

	def next_unlabeled_appearance_path
		# Rather than just getting the newest unlabeled pet state, prioritize the
		# newest *pet type*. This better matches the user's perception of what the
		# newest state is, because the Rainbow Pool UI is grouped by pet type!
		unlabeled_appearance = PetState.needs_labeling.newest_pet_type.newest.first

		if unlabeled_appearance
			edit_pet_type_pet_state_path(
				unlabeled_appearance.pet_type,
				unlabeled_appearance,
				next: "unlabeled-appearance"
			)
		else
			@pet_type
		end
	end
end
