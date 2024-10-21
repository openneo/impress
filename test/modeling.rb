require 'test_helper'

class ModelingTest < ActiveSupport::TestCase
	test "Modeling thyassa gives us Purple Chia data" do
		thyassa = Pet.load("thyassa")

		# The Purple Chia starts as a new record, hooked up to the existing
		# Purple color and Chia species.
		purple_chia = thyassa.pet_type
		assert purple_chia.new_record?
		assert_equal Color.find_by_name("purple"), purple_chia.color
		assert_equal Species.find_by_name("chia"), purple_chia.species
		assert_equal 212, purple_chia.body_id
		assert_equal "mock-image-hash:thyassa", purple_chia.image_hash
	end
end
