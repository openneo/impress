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
			"(Unknown)"
		end
	end
end
