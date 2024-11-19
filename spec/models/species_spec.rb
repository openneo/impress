require_relative '../rails_helper'

RSpec.describe Species do
	fixtures :species

	describe '#to_param' do
		it("uses name when possible") do
			expect(species(:acara).to_param).to eq "Acara"
		end

		it("uses IDs for new species") do
			expect(Species.new(id: 12345).to_param).to eq "12345"
		end
	end

	describe ".param_to_id" do
		it("looks up by name") do
			expect(Species.param_to_id("acara")).to eq species(:acara).id
		end

		it("is case-insensitive for name") do
			expect(Species.param_to_id("aCaRa")).to eq species(:acara).id
		end

		it("returns ID when the param is just a number, even if no record exists") do
			expect(Species.param_to_id("123456")).to eq 123456
		end

		it("raises RecordNotFound if no name matches") do
			expect { Species.param_to_id("nonexistant") }.
				to raise_error ActiveRecord::RecordNotFound
		end
	end
end
