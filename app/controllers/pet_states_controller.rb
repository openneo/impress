class PetStatesController < ApplicationController
	before_action :support_staff_only
	before_action :find_pet_state
	before_action :preload_assets

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

	def preload_assets
		SwfAsset.preload_manifests @pet_state.swf_assets
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
		unlabeled_appearance =
			PetState.next_unlabeled_appearance(after_id: params[:after])

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
