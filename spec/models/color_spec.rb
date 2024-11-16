require 'rails_helper'

RSpec.describe Color do
	fixtures :colors

	describe '#to_param' do
		it("uses name when possible") do
			expect(colors(:blue).to_param).to eq "Blue"
		end

		it("uses spaces for multi-word names") do
			expect(colors(:swamp_gas).to_param).to eq "Swamp Gas"
		end

		it("uses IDs for new colors") do
			expect(Color.new(id: 12345).to_param).to eq "12345"
		end
	end

	describe ".param_to_id" do
		it("looks up by name") do
			expect(Color.param_to_id("blue")).to eq colors(:blue).id
		end

		it("is case-insensitive for name") do
			expect(Color.param_to_id("bLUe")).to eq colors(:blue).id
		end

		it("returns ID when the param is just a number, even if it doesn't exist") do
			expect(Color.param_to_id("123456")).to eq 123456
		end

		it("raises RecordNotFound if no name matches") do
			expect { Color.param_to_id("nonexistant") }.
				to raise_error ActiveRecord::RecordNotFound
		end
	end
end
