require_relative '../rails_helper'

RSpec.describe Outfit do
	fixtures :zones, :colors, :species

	# Helper to create a pet state with specific swf_assets
	def build_pet_state(pet_type, pose: "HAPPY_FEM", swf_assets: [])
		pet_state = PetState.create!(
			pet_type: pet_type,
			pose: pose,
			swf_asset_ids: swf_assets.map(&:id)
		)
		pet_state.swf_assets = swf_assets
		pet_state
	end

	# Helper to create a SwfAsset for biology (pet layers)
	def build_biology_asset(zone, body_id:, zones_restrict: "")
		@remote_id = (@remote_id || 0) + 1
		SwfAsset.create!(
			type: "biology",
			remote_id: @remote_id,
			url: "https://images.neopets.example/biology_#{@remote_id}.swf",
			zone: zone,
			body_id: body_id,
			zones_restrict: zones_restrict
		)
	end

	# Helper to create a SwfAsset for items (object layers)
	def build_item_asset(zone, body_id:, zones_restrict: "")
		@remote_id = (@remote_id || 0) + 1
		SwfAsset.create!(
			type: "object",
			remote_id: @remote_id,
			url: "https://images.neopets.example/object_#{@remote_id}.swf",
			zone: zone,
			body_id: body_id,
			zones_restrict: zones_restrict
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

	describe "#visible_layers" do
		before do
			# Clean up any existing pet types to avoid conflicts
			PetType.destroy_all

			# Create a basic pet type for testing
			@pet_type = PetType.create!(
				species: species(:acara),
				color: colors(:blue),
				body_id: 1,
				created_at: Time.new(2005)
			)
		end

		context "basic layer composition" do
			it "returns pet layers when no items are worn" do
				# Create biology assets for the pet
				head = build_biology_asset(zones(:head), body_id: 1)
				body = build_biology_asset(zones(:body), body_id: 1)

				pet_state = build_pet_state(@pet_type, swf_assets: [head, body])
				outfit = Outfit.new(pet_state: pet_state)

				layers = outfit.visible_layers

				expect(layers).to contain_exactly(head, body)
			end

			it "returns pet layers and item layers when items are worn" do
				# Create pet layers
				head = build_biology_asset(zones(:head), body_id: 1)
				body = build_biology_asset(zones(:body), body_id: 1)
				pet_state = build_pet_state(@pet_type, swf_assets: [head, body])

				# Create item layers
				hat_asset = build_item_asset(zones(:hat), body_id: 1)
				hat = build_item("Test Hat", swf_assets: [hat_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hat]

				layers = outfit.visible_layers

				expect(layers).to contain_exactly(head, body, hat_asset)
			end

			it "includes body_id=0 items that fit all pets" do
				# Create pet layers
				head = build_biology_asset(zones(:head), body_id: 1)
				pet_state = build_pet_state(@pet_type, swf_assets: [head])

				# Create a background item (body_id=0, fits all)
				bg_asset = build_item_asset(zones(:background), body_id: 0)
				background = build_item("Test Background", swf_assets: [bg_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [background]

				layers = outfit.visible_layers

				expect(layers).to contain_exactly(head, bg_asset)
			end
		end

		context "items restricting pet layers (Rule 3a)" do
			it "hides pet layers in zones that items restrict" do
				# Create pet layers including hair
				head = build_biology_asset(zones(:head), body_id: 1)
				hair = build_biology_asset(zones(:hairfront), body_id: 1)
				pet_state = build_pet_state(@pet_type, swf_assets: [head, hair])

				# Create a hat that restricts the hair zone
				# zones_restrict is a bitfield where position 37 (Hair Front zone id) is "1"
				zones_restrict = "0" * 36 + "1" + "0" * 20 # bit 37 = 1
				hat_asset = build_item_asset(zones(:hat), body_id: 1, zones_restrict: zones_restrict)
				hat = build_item("Hair-hiding Hat", swf_assets: [hat_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hat]

				layers = outfit.visible_layers

				# Hair should be hidden, but head and hat should be visible
				expect(layers).to contain_exactly(head, hat_asset)
				expect(layers).not_to include(hair)
			end

			it "hides multiple pet layers when item restricts multiple zones" do
				# Create pet layers
				head = build_biology_asset(zones(:head), body_id: 1)
				hair_front = build_biology_asset(zones(:hairfront), body_id: 1)
				head_transient = build_biology_asset(zones(:headtransientbiology), body_id: 1)
				pet_state = build_pet_state(@pet_type, swf_assets: [head, hair_front, head_transient])

				# Create an item that restricts both Hair Front (37) and Head Transient Biology (38)
				zones_restrict = "0" * 36 + "11" + "0" * 20 # bits 37 and 38 = 1
				hood_asset = build_item_asset(zones(:hat), body_id: 1, zones_restrict: zones_restrict)
				hood = build_item("Agent Hood", swf_assets: [hood_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hood]

				layers = outfit.visible_layers

				# Both hair_front and head_transient should be hidden
				expect(layers).to contain_exactly(head, hood_asset)
				expect(layers).not_to include(hair_front, head_transient)
			end
		end

		context "pets restricting body-specific item layers (Rule 3b)" do
			it "hides body-specific items in zones the pet restricts" do
				# Create a pet with a layer that restricts the Static zone (46)
				head = build_biology_asset(zones(:head), body_id: 1)
				zones_restrict = "0" * 45 + "1" + "0" * 10 # bit 46 = 1
				restricting_layer = build_biology_asset(zones(:body), body_id: 1, zones_restrict: zones_restrict)
				pet_state = build_pet_state(@pet_type, swf_assets: [head, restricting_layer])

				# Create a body-specific Static item
				static_asset = build_item_asset(zones(:static), body_id: 1)
				static_item = build_item("Body-specific Static", swf_assets: [static_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [static_item]

				layers = outfit.visible_layers

				# The body-specific static item should be hidden
				expect(layers).to contain_exactly(head, restricting_layer)
				expect(layers).not_to include(static_asset)
			end

			it "allows body_id=0 items even in zones the pet restricts" do
				# Create a pet with a layer that restricts the Background Item zone (48)
				# Background Item is type_id 3 (universal zone), so body_id=0 items should always work
				head = build_biology_asset(zones(:head), body_id: 1)
				zones_restrict = "0" * 47 + "1" + "0" * 10 # bit 48 = 1
				restricting_layer = build_biology_asset(zones(:body), body_id: 1, zones_restrict: zones_restrict)
				pet_state = build_pet_state(@pet_type, swf_assets: [head, restricting_layer])

				# Create a body_id=0 Background Item (fits all bodies, universal zone)
				bg_item_asset = build_item_asset(zones(:backgrounditem), body_id: 0)
				bg_item = build_item("Universal Background Item", swf_assets: [bg_item_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [bg_item]

				layers = outfit.visible_layers

				# The body_id=0 item should be visible even though the zone is restricted
				expect(layers).to contain_exactly(head, restricting_layer, bg_item_asset)
			end
		end

		context "UNCONVERTED pets (Rule 3b special case)" do
			it "rejects all body-specific items" do
				# Create an UNCONVERTED pet
				head = build_biology_asset(zones(:head), body_id: 1)
				body = build_biology_asset(zones(:body), body_id: 1)
				pet_state = build_pet_state(@pet_type, pose: "UNCONVERTED", swf_assets: [head, body])

				# Create both body-specific and body_id=0 items
				body_specific_asset = build_item_asset(zones(:hat), body_id: 1)
				body_specific_item = build_item("Body-specific Hat", swf_assets: [body_specific_asset])

				universal_asset = build_item_asset(zones(:background), body_id: 0)
				universal_item = build_item("Universal Background", swf_assets: [universal_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [body_specific_item, universal_item]

				layers = outfit.visible_layers

				# Only body_id=0 items should be visible
				expect(layers).to contain_exactly(head, body, universal_asset)
				expect(layers).not_to include(body_specific_asset)
			end

			it "rejects body-specific items regardless of zone restrictions" do
				# Create an UNCONVERTED pet with no zone restrictions
				head = build_biology_asset(zones(:head), body_id: 1)
				pet_state = build_pet_state(@pet_type, pose: "UNCONVERTED", swf_assets: [head])

				# Create a body-specific item in a zone the pet doesn't restrict
				hat_asset = build_item_asset(zones(:hat), body_id: 1)
				hat = build_item("Body-specific Hat", swf_assets: [hat_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hat]

				layers = outfit.visible_layers

				# The body-specific item should still be hidden
				expect(layers).to contain_exactly(head)
				expect(layers).not_to include(hat_asset)
			end
		end

		context "pets restricting their own layers (Rule 3c)" do
			it "hides pet layers in zones the pet itself restricts" do
				# Create a pet with a horn asset and a layer that restricts the horn's zone
				# (Simulating the Wraith Uni case)
				body = build_biology_asset(zones(:body), body_id: 1)

				# Create a horn in the Head Transient Biology zone (38)
				horn = build_biology_asset(zones(:headtransientbiology), body_id: 1)

				# Create a layer that restricts zone 38
				zones_restrict = "0" * 37 + "1" + "0" * 20 # bit 38 = 1
				restricting_layer = build_biology_asset(zones(:head), body_id: 1, zones_restrict: zones_restrict)

				pet_state = build_pet_state(@pet_type, swf_assets: [body, horn, restricting_layer])

				outfit = Outfit.new(pet_state: pet_state)

				layers = outfit.visible_layers

				# The horn should be hidden by the pet's own restrictions
				expect(layers).to contain_exactly(body, restricting_layer)
				expect(layers).not_to include(horn)
			end

			it "applies self-restrictions in combination with item restrictions" do
				# Create a pet with multiple layers, some restricted by itself
				body = build_biology_asset(zones(:body), body_id: 1)
				hair = build_biology_asset(zones(:hairfront), body_id: 1)

				# Pet restricts its own Head zone (30)
				zones_restrict = "0" * 29 + "1" + "0" * 25 # bit 30 = 1
				head = build_biology_asset(zones(:head), body_id: 1)
				restricting_layer = build_biology_asset(zones(:eyes), body_id: 1, zones_restrict: zones_restrict)

				pet_state = build_pet_state(@pet_type, swf_assets: [body, hair, head, restricting_layer])

				# Add an item that restricts Hair Front (37)
				item_zones_restrict = "0" * 36 + "1" + "0" * 20 # bit 37 = 1
				hat_asset = build_item_asset(zones(:hat), body_id: 1, zones_restrict: item_zones_restrict)
				hat = build_item("Hair-hiding Hat", swf_assets: [hat_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hat]

				layers = outfit.visible_layers

				# Hair should be hidden by item, Head should be hidden by pet's own restrictions
				expect(layers).to contain_exactly(body, restricting_layer, hat_asset)
				expect(layers).not_to include(hair, head)
			end
		end

		context "depth sorting and layer ordering" do
			it "sorts layers by zone depth" do
				# Create layers in various zones with different depths
				background = build_biology_asset(zones(:background), body_id: 1) # depth 3
				body_layer = build_biology_asset(zones(:body), body_id: 1)       # depth 18
				head_layer = build_biology_asset(zones(:head), body_id: 1)       # depth 34

				pet_state = build_pet_state(@pet_type, swf_assets: [head_layer, background, body_layer])

				outfit = Outfit.new(pet_state: pet_state)

				layers = outfit.visible_layers

				# Should be sorted by depth: background (3) < body (18) < head (34)
				expect(layers[0]).to eq(background)
				expect(layers[1]).to eq(body_layer)
				expect(layers[2]).to eq(head_layer)
			end

			it "places item layers after pet layers at the same depth" do
				# Create a pet layer and item layer in zones with the same depth
				# Static zone has depth 48
				pet_static = build_biology_asset(zones(:static), body_id: 1)
				pet_state = build_pet_state(@pet_type, swf_assets: [pet_static])

				item_static = build_item_asset(zones(:static), body_id: 0)
				static_item = build_item("Static Item", swf_assets: [item_static])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [static_item]

				layers = outfit.visible_layers

				# Both should be present, with item layer last (on top)
				expect(layers).to eq([pet_static, item_static])
			end

			it "sorts complex outfits correctly by depth" do
				# Create a complex outfit with multiple pet and item layers
				background = build_biology_asset(zones(:background), body_id: 1)  # depth 3
				body_layer = build_biology_asset(zones(:body), body_id: 1)        # depth 18
				head_layer = build_biology_asset(zones(:head), body_id: 1)        # depth 34

				pet_state = build_pet_state(@pet_type, swf_assets: [head_layer, background, body_layer])

				# Add items at various depths
				bg_item = build_item_asset(zones(:backgrounditem), body_id: 0)    # depth 4
				hat_asset = build_item_asset(zones(:hat), body_id: 1)             # depth 16
				shirt_asset = build_item_asset(zones(:shirtdress), body_id: 1)    # depth 26

				bg = build_item("Background Item", swf_assets: [bg_item])
				hat = build_item("Hat", swf_assets: [hat_asset])
				shirt = build_item("Shirt", swf_assets: [shirt_asset])

				outfit = Outfit.new(pet_state: pet_state)
				outfit.worn_items = [hat, bg, shirt]

				layers = outfit.visible_layers

				# Expected order by depth:
				# background (3), bg_item (4), hat_asset (16), body_layer (18),
				# shirt_asset (26), head_layer (34)
				expect(layers.map(&:depth)).to eq([3, 4, 16, 18, 26, 34])
				expect(layers).to eq([background, bg_item, hat_asset, body_layer, shirt_asset, head_layer])
			end
		end
	end
end
