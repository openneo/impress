require_relative '../../rails_helper'
require_relative '../../support/mocks/custom_pets'
require_relative '../../support/mocks/nc_mall'

RSpec.describe Pet::AutoModeling, type: :model do
  fixtures :colors, :species, :zones

  # Set up a Purple Chia pet type (body_id 212) for testing
  let!(:pet_type) do
    PetType.create!(
      species_id: Species.find_by_name!("chia").id,
      color_id: Color.find_by_name!("purple").id,
      body_id: 212,
      image_hash: "purpchia"
    )
  end

  # A known compatible item for testing (exists in mock data)
  let(:compatible_item) do
    Item.create!(
      id: 71706,
      name: "On the Roof Background",
      description: "Who is that on the roof?! Could it be...?",
      thumbnail_url: "https://images.neopets.com/items/gif_roof_onthe_fg.gif",
      rarity: "Special",
      rarity_index: 101,
      price: 0,
      zones_restrict: "0000000000000000000000000000000000000000000000000000"
    )
  end

  describe ".model_item_on_body" do
    context "when item is compatible with the body" do
      let(:item) { compatible_item }

      it "returns :modeled" do
        result = Pet::AutoModeling.model_item_on_body(item, 212)
        expect(result).to eq :modeled
      end

      it "creates SwfAsset records for the item" do
        expect {
          Pet::AutoModeling.model_item_on_body(item, 212)
        }.to change { SwfAsset.where(type: "object").count }.by(1)
      end

      it "associates the SwfAsset with the item" do
        Pet::AutoModeling.model_item_on_body(item, 212)
        item.reload

        asset = item.swf_assets.find_by(remote_id: 410722)
        expect(asset).to be_present
        expect(asset.body_id).to eq 0 # This item fits all bodies
        expect(asset.zone_id).to eq 3
      end
    end

    context "when item is not in the response" do
      let(:item) do
        # Create an item that won't be in our mock response
        Item.create!(
          id: 99999,
          name: "Nonexistent Item",
          description: "This item doesn't exist in the mock",
          thumbnail_url: "https://example.com/item.gif",
          rarity: "Special",
          rarity_index: 101,
          price: 0,
          zones_restrict: "0000000000000000000000000000000000000000000000000000"
        )
      end

      it "returns :not_compatible" do
        result = Pet::AutoModeling.model_item_on_body(item, 212)
        expect(result).to eq :not_compatible
      end
    end

    context "when no PetType exists for the body_id" do
      let(:item) { compatible_item }

      it "raises NoPetTypeForBody" do
        expect {
          Pet::AutoModeling.model_item_on_body(item, 99999)
        }.to raise_error(Pet::AutoModeling::NoPetTypeForBody) do |error|
          expect(error.body_id).to eq 99999
          expect(error.message).to include "99999"
        end
      end
    end
  end
end
