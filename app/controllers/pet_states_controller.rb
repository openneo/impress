class PetStatesController < ApplicationController
	before_action :find_pet_state
	before_action :support_staff_only, except: [:show]

	def show
	end

	def edit
	end

	def update
		if @pet_state.update(pet_state_params)
			flash[:notice] = "Pet appearance \##{@pet_state.id} successfully saved!"
			redirect_to @pet_type
		else
			render action: :edit, status: :bad_request
		end
	end

	protected

	def find_pet_state
		@pet_type = PetType.matching_name_param(params[:pet_type_name]).first!
		@pet_state = @pet_type.pet_states.find(params[:id])
	end

	def pet_state_params
		params.require(:pet_state).permit(:pose, :glitched)
	end
end
