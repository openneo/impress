require 'rails_helper'

RSpec.describe PetType do
	fixtures :colors, :species, :pet_types

	describe '#to_param' do
		it('uses color and species name when possible ("Blue-Acara")') do
			expect(pet_types(:blue_acara).to_param).to eq "Blue-Acara"
		end

		it('uses color ID for new colors (123-Acara)') do
			expect(pet_types(:newcolor_acara).to_param).to eq "123-Acara"
		end

		it('uses species ID for new colors (Blue-456)') do
			expect(pet_types(:blue_newspecies).to_param).to eq "Blue-456"
		end

		it('uses color ID and species ID when both are new (123-456)') do
			expect(pet_types(:newcolor_newspecies).to_param).to eq "123-456"
		end
	end

	describe ".find_by_param!" do
		it('looks up by species and color name ("Blue-Acara")') do
			expect(PetType.find_by_param!("Blue-Acara")).to eq pet_types(:blue_acara)
		end

		it('looks up by color ID for new colors ("123-Acara")') do
			expect(PetType.find_by_param!("123-Acara")).to eq pet_types(:newcolor_acara)
		end

		it('looks up by species ID for new species ("Blue-456")') do
			expect(PetType.find_by_param!("Blue-456")).to eq pet_types(:blue_newspecies)
		end

		it('looks up by color ID and species ID when both are new ("123-456")') do
			expect(PetType.find_by_param!("123-456")).to eq pet_types(:newcolor_newspecies)
		end
	end
end
