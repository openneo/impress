require_relative '../rails_helper'

RSpec.describe Item do
	fixtures :items, :colors, :species, :zones

	context "modeling status:" do
		# Rather than using fixtures of real-world data, we create very specific
		# pet types, to be able to create small encapsulated test cases where there
		# are only a few bodies.
		#
		# We create some basic color pet types, and some Maraquan pet types—and,
		# just like irl, the Maraquan Mynci has the same body as the basic Mynci.
		before do
			PetType.destroy_all # Make sure no leftovers from e.g. PetType's spec!

			build_pt(colors(:blue),  species(:acara),    body_id: 1).save!
			build_pt(colors(:red),   species(:acara),    body_id: 1).save!
			build_pt(colors(:blue),  species(:blumaroo), body_id: 2).save!
			build_pt(colors(:green), species(:chia),     body_id: 3).save!
			build_pt(colors(:red),   species(:mynci),    body_id: 4).save!

			build_pt(colors(:maraquan),  species(:acara),    body_id: 11).save!
			build_pt(colors(:maraquan),  species(:blumaroo), body_id: 12).save!
			build_pt(colors(:maraquan),  species(:chia),     body_id: 13).save!
			build_pt(colors(:maraquan),  species(:mynci),    body_id: 4).save!
		end

		def build_pt(color, species, body_id:)
			PetType.new(color:, species:, body_id:)
		end

		def build_item_asset(zone, body_id:)
			@remote_id = (@remote_id || 0) + 1
			url = "https://images.neopets.example/#{@remote_id}.swf"
			SwfAsset.new(type: "object", remote_id: @remote_id, url:,
			             zones_restrict: "", zone:, body_id:)
		end

		shared_examples "a fully-modeled item" do
			it("is considered fully modeled") { should be_predicted_fully_modeled }
			it("predicts no more compatible bodies") do
				expect(item.predicted_missing_body_ids).to be_empty
			end
			pending("appears in Item.is_modeled") do
				expect(Item.is_modeled.find(item.id)).to be_present
			end
			pending("does not appear in Item.is_not_modeled") do
				expect(Item.is_not_modeled.find(item.id)).to be_nil
			end
		end

		shared_examples "a not-fully-modeled item" do
			it("is not fully modeled") { should_not be_predicted_fully_modeled }
			pending("does not appear in Item.is_modeled") do
				expect(Item.is_modeled.find(item.id)).to be_nil
			end
			pending("appears in in Item.is_not_modeled") do
				expect(Item.is_not_modeled.find(item.id)).to be_present
			end
		end

		describe "an item without any modeling data" do
			subject(:item) { items(:straw_hat) }

			it_behaves_like "a not-fully-modeled item"
			it("has no compatible body IDs") do
				expect(item.compatible_body_ids).to be_empty
			end
			it("predicts all standard bodies are compatible") do
				expect(item.predicted_missing_body_ids).to contain_exactly(1, 2, 3, 4)
			end
		end

		describe "an item with one species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 1)
			end

			it_behaves_like "a fully-modeled item"
			it("has one compatible body ID") do
				expect(item.compatible_body_ids).to contain_exactly(1)
			end
		end

		describe "an item with two species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 1)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 2)
			end

			it_behaves_like "a not-fully-modeled item"
			it("has two compatible body IDs") do
				expect(item.compatible_body_ids).to contain_exactly(1, 2)
			end
			it("predicts remaining standard bodies are compatible") do
				expect(item.predicted_missing_body_ids).to contain_exactly(3, 4)
			end
		end

		describe "an item with all standard species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 1)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 2)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 3)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 4)
			end

			it_behaves_like "a fully-modeled item"
			it("is compatible with all standard body IDs") do
				expect(item.compatible_body_ids).to contain_exactly(1, 2, 3, 4)
			end
		end

		describe "an item that fits all pets the same" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:background), body_id: 0)
			end

			it_behaves_like "a fully-modeled item"
			it("is compatible with all bodies (body ID = 0)") do
				expect(item.compatible_body_ids).to contain_exactly(0)
			end
		end

		describe "an item with one Maraquan pet modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 11)
			end

			it_behaves_like "a fully-modeled item"
			it("has one compatible body ID") do
				expect(item.compatible_body_ids).to contain_exactly(11)
			end
		end

		describe "an item with two Maraquan pets modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 11)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 12)
			end

			it_behaves_like "a not-fully-modeled item"
			it("has two compatible body IDs") do
				expect(item.compatible_body_ids).to contain_exactly(11, 12)
			end
			it("predicts remaining Maraquan body IDs are compatible") do
				expect(item.predicted_missing_body_ids).to contain_exactly(13, 4)
			end
		end

		describe "an item with all Maraquan species modeled" do
			subject(:item) { items(:straw_hat) }

			before do
				item.swf_assets << build_item_asset(zones(:wings), body_id: 11)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 12)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 13)
				item.swf_assets << build_item_asset(zones(:wings), body_id: 4)
			end

			it_behaves_like "a fully-modeled item"
			it("is compatible with all Maraquan body IDs") do
				expect(item.compatible_body_ids).to contain_exactly(11, 12, 13, 4)
			end
		end
	end
end
