require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe OutfitImageRenderer do
  fixtures :zones, :colors, :species

  # Helper to create a simple PNG image (1x1 pixel) with a specific color
  def create_test_png(red, green, blue, alpha = 255)
    require 'vips'
    image = Vips::Image.black(1, 1, bands: 4)
    image = image.new_from_image([red, green, blue, alpha])
    image.write_to_buffer('.png')
  end

  # Helper to create a pet state with specific swf_assets
  def build_pet_state(pet_type, pose: "HAPPY_FEM", swf_assets: [])
    pet_state = PetState.create!(
      pet_type: pet_type,
      pose: pose,
      swf_asset_ids: swf_assets.empty? ? [0] : swf_assets.map(&:id)
    )
    pet_state.swf_assets = swf_assets
    pet_state
  end

  # Helper to create a SwfAsset for biology (pet layers)
  def build_biology_asset(zone, body_id:)
    @remote_id = (@remote_id || 0) + 1
    SwfAsset.create!(
      type: "biology",
      remote_id: @remote_id,
      url: "https://images.neopets.example/biology_#{@remote_id}.swf",
      zone: zone,
      body_id: body_id,
      zones_restrict: "",
      has_image: true
    )
  end

  # Helper to create a SwfAsset for items (object layers)
  def build_item_asset(zone, body_id:)
    @remote_id = (@remote_id || 0) + 1
    SwfAsset.create!(
      type: "object",
      remote_id: @remote_id,
      url: "https://images.neopets.example/object_#{@remote_id}.swf",
      zone: zone,
      body_id: body_id,
      zones_restrict: "",
      has_image: true
    )
  end

  # Helper to create an item with specific swf_assets
  def build_item(name, swf_assets: [])
    item = Item.create!(
      name: name,
      description: "Test item",
      thumbnail_url: "https://images.neopets.example/thumbnail.png",
      rarity: "Common",
      price: 100,
      zones_restrict: "",
      species_support_ids: ""
    )
    swf_assets.each do |asset|
      ParentSwfAssetRelationship.create!(
        parent: item,
        swf_asset: asset
      )
    end
    item
  end

  before do
    PetType.destroy_all
    @pet_type = PetType.create!(
      species: species(:acara),
      color: colors(:blue),
      body_id: 1,
      created_at: Time.new(2005)
    )
  end

  describe "#render" do
    context "with a simple outfit" do
      it "composites biology and item layers into a single PNG" do
        # Create test PNG data
        red_png = create_test_png(255, 0, 0)    # Red pixel
        blue_png = create_test_png(0, 0, 255)   # Blue pixel

        # Create biology and item assets
        biology_asset = build_biology_asset(zones(:head), body_id: 1)
        item_asset = build_item_asset(zones(:hat), body_id: 1)

        # Stub HTTP requests for the actual image URLs that will be generated
        stub_request(:get, biology_asset.image_url).
          to_return(body: red_png, status: 200)
        stub_request(:get, item_asset.image_url).
          to_return(body: blue_png, status: 200)

        # Build outfit
        pet_state = build_pet_state(@pet_type, swf_assets: [biology_asset])
        item = build_item("Test Hat", swf_assets: [item_asset])
        outfit = Outfit.new(pet_state: pet_state)
        outfit.item_ids = { worn: [item.id], closeted: [] }

        # Render
        renderer = OutfitImageRenderer.new(outfit)
        result = renderer.render

        # Verify we got PNG data back
        expect(result).not_to be_nil
        expect(result).to be_a(String)
        expect(result[0..7]).to eq("\x89PNG\r\n\x1A\n".b) # PNG magic bytes

        # Verify the result is a valid 600x600 PNG
        image = Vips::Image.new_from_buffer(result, "")
        expect(image.width).to eq(600)
        expect(image.height).to eq(600)
      end
    end

    context "when a layer image fails to load" do
      it "skips the failed layer and continues" do
        blue_png = create_test_png(0, 0, 255)

        biology_asset = build_biology_asset(zones(:head), body_id: 1)
        item_asset = build_item_asset(zones(:hat), body_id: 1)

        # Stub one successful request and one failure
        stub_request(:get, biology_asset.image_url).
          to_return(status: 404)
        stub_request(:get, item_asset.image_url).
          to_return(body: blue_png, status: 200)

        pet_state = build_pet_state(@pet_type, swf_assets: [biology_asset])
        item = build_item("Test Hat", swf_assets: [item_asset])
        outfit = Outfit.new(pet_state: pet_state)
        outfit.item_ids = { worn: [item.id], closeted: [] }

        renderer = OutfitImageRenderer.new(outfit)
        result = renderer.render

        # Should still render successfully with just the one layer
        expect(result).not_to be_nil
        expect(result[0..7]).to eq("\x89PNG\r\n\x1A\n".b)
      end
    end

    context "when no layers have images" do
      it "returns nil" do
        # Create an asset but stub image_url to return nil
        biology_asset = build_biology_asset(zones(:head), body_id: 1)
        allow_any_instance_of(SwfAsset).to receive(:image_url?).and_return(false)

        pet_state = build_pet_state(@pet_type, swf_assets: [biology_asset])
        outfit = Outfit.new(pet_state: pet_state)

        renderer = OutfitImageRenderer.new(outfit)
        result = renderer.render

        expect(result).to be_nil
      end
    end
  end
end
