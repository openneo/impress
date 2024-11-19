require_relative '../rails_helper'

RSpec.describe Item do
	fixtures :items, :colors, :species, :zones

	context "modeling status:" do
		# Rather than using fixtures of real-world data, we create very specific
		# pet types, to be able to create small encapsulated test cases where there
		# are only a few bodies.
		before do
			PetType.destroy_all # Make sure no leftovers from e.g. PetType's spec!
			build_pt(colors(:blue),  species(:acara),    body_id: 1).save!
			build_pt(colors(:red),   species(:acara),    body_id: 1).save!
			build_pt(colors(:green), species(:blumaroo), body_id: 2).save!
			build_pt(colors(:red),   species(:chia),     body_id: 3).save!
		end

		def build_pt(color, species, body_id:)
			PetType.new(color:, species:, body_id:)
		end

		def build_item_asset(zone, body_id:)
			@remote_id = (@remote_id || 0) + 1
			@url = "https://images.neopets.example/#{@remote_id}.swf"
			SwfAsset.new(type: "object", remote_id: @remote_id, url: @url,
			             zones_restrict: "", zone:, body_id:)
		end

		describe "an item without any modeling data" do
			subject(:item) { items(:straw_hat) }

			it("is not fully modeled") { should_not be_predicted_fully_modeled }
			it("has no compatible body IDs") do
				expect(item.compatible_body_ids).to be_empty
			end
			it("predicts all standard bodies are compatible") do
				expect(item.predicted_missing_body_ids).to contain_exactly(1, 2, 3)
			end
		end

		describe "an item with one species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 1)
			end

			it("is considered fully modeled") { should be_predicted_fully_modeled }
			it("has one compatible body ID") do
				expect(item.compatible_body_ids).to contain_exactly(1)
			end
			it("predicts no more compatible bodies") do
				expect(item.predicted_missing_body_ids).to be_empty
			end
		end

		describe "an item with two species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 1)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 2)
				# HACK: I don't understand why the first asset is triggering the hooks
				#       for cached fields, but the second isn't? Idk, force an update.
				item.update_cached_fields
			end

			it("is not fully modeled") { should_not be_predicted_fully_modeled }
			it("has two compatible body IDs") do
				expect(item.compatible_body_ids).to contain_exactly(1, 2)
			end
			it("predicts remaining standard bodies are compatible") do
				expect(item.predicted_missing_body_ids).to contain_exactly(3)
			end
		end

		describe "an item that fits all pets the same" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:background), body_id: 0)
			end

			it("is fully modeled") { should be_predicted_fully_modeled }
			it("is compatible with all bodies (body ID = 0)") do
				expect(item.compatible_body_ids).to contain_exactly(0)
			end
			it("predicts no more compatible bodies") do
				expect(item.predicted_missing_body_ids).to be_empty
			end
		end

		pending("Don't forget special colors!") { fail }
	end
end
