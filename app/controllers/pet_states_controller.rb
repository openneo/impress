class PetStatesController < ApplicationController
	def show
		@pet_type = PetType.matching_name_param(params[:pet_type_name]).first!
		@pet_state = @pet_type.pet_states.find(params[:id])
	end
end
