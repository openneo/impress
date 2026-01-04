require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe OutfitImageRenderer do
  fixtures :zones, :colors, :species

  # Helper to load a fixture image
  def load_fixture_image(filename)
    path = Rails.root.join('spec', 'fixtures', 'outfit_images', filename)
    File.read(path)
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
        # Load fixture images
        acara_png = load_fixture_image('Blue Acara.png')
        hat_png = load_fixture_image('Hat.png')
        expected_composite_png = load_fixture_image('Blue Acara With Hat.png')

        # Create biology and item assets
        biology_asset = build_biology_asset(zones(:head), body_id: 1)
        item_asset = build_item_asset(zones(:hat1), body_id: 1)

        # Stub HTTP requests for the actual image URLs that will be generated
        stub_request(:get, biology_asset.image_url).
          to_return(body: acara_png, status: 200)
        stub_request(:get, item_asset.image_url).
          to_return(body: hat_png, status: 200)

        # Build outfit
        pet_state = build_pet_state(@pet_type, swf_assets: [biology_asset])
        item = build_item("Test Hat", swf_assets: [item_asset])
        outfit = Outfit.new(
          pet_state: pet_state,
          worn_items: [item]
        )

        # Render
        renderer = OutfitImageRenderer.new(outfit)
        result = renderer.render

        # Verify we got PNG data back
        expect(result).not_to be_nil
        expect(result).to be_a(String)
        expect(result[0..7]).to eq("\x89PNG\r\n\x1A\n".b) # PNG magic bytes

        # Verify the result is a valid 600x600 PNG
        result_image = Vips::Image.new_from_buffer(result, "")
        expect(result_image.width).to eq(600)
        expect(result_image.height).to eq(600)

        # Verify the composite matches the expected image pixel-perfectly
        expected_image = Vips::Image.new_from_buffer(expected_composite_png, "")

        # Calculate the absolute difference between images
        diff = (result_image - expected_image).abs
        max_diff = diff.max

        # Allow a small tolerance for minor encoding/compositing differences
        # The expected image was generated with a different method, so we expect
        # very close but not necessarily pixel-perfect matches
        tolerance = 2
        if max_diff > tolerance
          debug_path = Rails.root.join('tmp', 'test_render_result.png')
          result_image.write_to_file(debug_path.to_s)
          fail "Images should match within tolerance of #{tolerance}, but found max difference of #{max_diff}. Actual output saved to #{debug_path}"
        end
      end
    end

    context "when a layer image fails to load" do
      it "skips the failed layer and continues" do
        hat_png = load_fixture_image('Hat.png')

        biology_asset = build_biology_asset(zones(:head), body_id: 1)
        item_asset = build_item_asset(zones(:hat1), body_id: 1)

        # Stub one successful request and one failure
        stub_request(:get, biology_asset.image_url).
          to_return(status: 404)
        stub_request(:get, item_asset.image_url).
          to_return(body: hat_png, status: 200)

        pet_state = build_pet_state(@pet_type, swf_assets: [biology_asset])
        item = build_item("Test Hat", swf_assets: [item_asset])
        outfit = Outfit.new(
          pet_state: pet_state,
          worn_items: [item]
        )

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
