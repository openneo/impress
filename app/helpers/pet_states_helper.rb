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

	POSE_OPTIONS = %w(UNKNOWN HAPPY_FEM HAPPY_MASC SAD_FEM SAD_MASC SICK_FEM
	                  SICK_MASC UNCONVERTED)
	def pose_options
		POSE_OPTIONS.map { |p| [pose_name(p), p] }
	end
end
