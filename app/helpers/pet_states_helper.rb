module PetStatesHelper
	def pose_name(pose)
		case pose
		when "HAPPY_FEM"
			"Happy (Feminine)"
		when "HAPPY_MASC"
			"Happy (Masculine)"
		when "SAD_FEM"
			"Sad (Feminine)"
		when "SAD_MASC"
			"Sad (Masculine)"
		when "SICK_FEM"
			"Sick (Feminine)"
		when "SICK_MASC"
			"Sick (Masculine)"
		when "UNCONVERTED"
			"Unconverted"
		else
			"Not labeled yet"
		end
	end

	POSE_OPTIONS = %w(HAPPY_FEM SAD_FEM SICK_FEM HAPPY_MASC SAD_MASC SICK_MASC
	                  UNCONVERTED UNKNOWN)
	def pose_options
		POSE_OPTIONS
	end

	def useful_pet_state_path(...)
		if support_staff?
			edit_pet_type_pet_state_path(...)
		else
			pet_type_pet_state_path(...)
		end
	end
end
