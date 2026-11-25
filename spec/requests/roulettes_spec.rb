require_relative '../rails_helper'
require 'cgi'

RSpec.describe "The roulette endpoint", type: :request do
	fixtures :colors, :species, :zones

	before do
		# The pet_types fixture has a blue/acara type, which would collide with
		# ours (pet types are unique per species+color).
		PetType.destroy_all
		PetState.destroy_all

		pet_type = PetType.create!(color: colors(:blue), species: species(:acara),
		                            body_id: 1, created_at: Time.new(2010))
		# (Like the rest of our specs, [0] means "no assets": Rails would save
		# an empty array as NULL, which this NOT NULL column rejects.)
		@pet_state = PetState.create!(pet_type:, mood_id: 1, female: true,
		                              swf_asset_ids: [0], labeled: true)

		# A hat that fits the pet's body, so spins can be dressed.
		restrict = Array.new(52, "0")
		@item = Item.create!(name: "Hat", description: "A test hat",
		                     thumbnail_url: "https://images.neopets.example/test.gif",
		                     rarity: "NP", price: 100, weight_lbs: 1,
		                     zones_restrict: restrict.join,
		                     cached_compatible_body_ids: [1],
		                     cached_occupied_zone_ids: [40])
	end

	it "redirects to the wardrobe, wearing a random pet and outfit" do
		get "/roulette"

		expect(response).to have_http_status(:redirect)

		params = CGI.parse(URI.parse(response.location).query)
		expect(params["color"]).to eq([colors(:blue).id.to_s])
		expect(params["species"]).to eq([species(:acara).id.to_s])
		expect(params["pose"]).to eq(["HAPPY_FEM"])
		expect(params["state"]).to eq([@pet_state.id.to_s])
		expect(params["objects[]"]).to eq([@item.id.to_s])
	end

	it "returns the random pet and outfit as JSON" do
		get "/roulette.json"

		expect(response).to have_http_status(:ok)

		body = JSON.parse(response.body)
		expect(body["color"]).to eq(colors(:blue).id)
		expect(body["species"]).to eq(species(:acara).id)
		expect(body["pose"]).to eq("HAPPY_FEM")
		expect(body["state"]).to eq(@pet_state.id)
		expect(body["objects"]).to eq([@item.id])

		# Shortcuts to the editor page and its rendering, wearing this spin.
		wardrobe_url = URI.parse(body["wardrobe_url"])
		png_url = URI.parse(body["png_url"])
		expect(wardrobe_url.path).to eq("/outfits/new")
		expect(png_url.path).to eq("/outfits/new.png")

		# Both point at the same spin.
		expect(wardrobe_url.query).to eq(png_url.query)

		params = CGI.parse(wardrobe_url.query)
		expect(params["color"]).to eq([colors(:blue).id.to_s])
		expect(params["species"]).to eq([species(:acara).id.to_s])
		expect(params["pose"]).to eq(["HAPPY_FEM"])
		expect(params["state"]).to eq([@pet_state.id.to_s])
		expect(params["objects[]"]).to eq([@item.id.to_s])
	end

	it "omits objects from JSON when no items fit" do
		Item.delete_all

		get "/roulette.json"

		body = JSON.parse(response.body)
		expect(body).not_to have_key("objects")
	end

	it "forwards PNG requests to the editor's image endpoint" do
		get "/roulette.png"

		expect(response).to have_http_status(:redirect)
		expect(URI.parse(response.location).path).to eq("/outfits/new.png")

		params = CGI.parse(URI.parse(response.location).query)
		expect(params["color"]).to eq([colors(:blue).id.to_s])
		expect(params["species"]).to eq([species(:acara).id.to_s])
		expect(params["pose"]).to eq(["HAPPY_FEM"])
		expect(params["state"]).to eq([@pet_state.id.to_s])
		expect(params["objects[]"]).to eq([@item.id.to_s])
	end

	it "400s on a bad param, even for PNG requests" do
		get "/roulette.png?species=dragon"

		expect(response).to have_http_status(:bad_request)
		expect(response.body).to eq("Unknown species: dragon")
	end

	it "never serves an error message as HTML, since it echoes the request" do
		payload = CGI.escape("<img src=x onerror=alert(1)>")

		["/roulette", "/roulette.png"].each do |path|
			get "#{path}?color=#{payload}"

			expect(response).to have_http_status(:bad_request)
			expect(response.media_type).to eq("text/plain")
			expect(response.body).to include("<img")
		end
	end

	it "400s on a full value that isn't a yes or a no" do
		get "/roulette.json?full=maybe"

		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to match(/full must be/)
	end

	it "400s on a count that isn't plain digits" do
		get "/roulette.json?count=1_0"

		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to match(/count/)
	end

	it "400s on the music and sound effects zones" do
		get "/roulette.json?zones=1"

		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to match(/can't be requested/)
	end

	it "dresses every zone when asked for a full outfit" do
		# Twelve more items in twelve zones the hat doesn't touch: that's more
		# than a capped spin can ever wear.
		restrict = Array.new(52, "0")
		Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(12).each_with_index do |zone, i|
			Item.create!(name: "Full #{i + 1}", description: "A test item",
			             thumbnail_url: "https://images.neopets.example/test.gif",
			             rarity: "NP", price: 100, weight_lbs: 1,
			             zones_restrict: restrict.join,
			             cached_compatible_body_ids: [1],
			             cached_occupied_zone_ids: [zone.id])
		end

		get "/roulette?full=1"
		params = CGI.parse(URI.parse(response.location).query)
		expect(params["objects[]"].size).to eq(13)

		# Without the param, the cap still applies.
		get "/roulette"
		params = CGI.parse(URI.parse(response.location).query)
		expect(params["objects[]"].size).to be_between(3, 10)
	end

	it "400s when mixing the dress-level params" do
		get "/roulette.json?full=1&count=5"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"])
			.to eq("full can't be combined with count or zones")

		get "/roulette.json?full=1&zones=40"
		expect(response).to have_http_status(:bad_request)

		get "/roulette.json?count=5&zones=40"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"])
			.to eq("count can't be combined with zones")

		# full combined with the pet params is fine, though.
		get "/roulette.json?full=1&species=acara"
		expect(response).to have_http_status(:ok)
	end

	it "fills exactly as many random zones as asked for" do
		# Twelve more items in twelve zones the hat doesn't touch.
		restrict = Array.new(52, "0")
		Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(12).each_with_index do |zone, i|
			Item.create!(name: "Count #{i + 1}", description: "A test item",
			             thumbnail_url: "https://images.neopets.example/test.gif",
			             rarity: "NP", price: 100, weight_lbs: 1,
			             zones_restrict: restrict.join,
			             cached_compatible_body_ids: [1],
			             cached_occupied_zone_ids: [zone.id])
		end

		get "/roulette?count=4"
		params = CGI.parse(URI.parse(response.location).query)
		expect(params["objects[]"].size).to eq(4)

		# ?count=0 is a bare pet.
		get "/roulette.json?count=0"
		expect(JSON.parse(response.body)).not_to have_key("objects")
	end

	it "fills the zones asked for" do
		restrict = Array.new(52, "0")
		shirt = Item.create!(name: "Shirt", description: "A test shirt",
		                     thumbnail_url: "https://images.neopets.example/test.gif",
		                     rarity: "NP", price: 100, weight_lbs: 1,
		                     zones_restrict: restrict.join,
		                     cached_compatible_body_ids: [1],
		                     cached_occupied_zone_ids: [23])

		get "/roulette?zones=40,23"
		params = CGI.parse(URI.parse(response.location).query)
		expect(params["objects[]"]).to match_array([@item.id.to_s, shirt.id.to_s])
	end

	it "spins only the requested species and/or color" do
		# A second pet type, so there's something else to pick from.
		pet_type2 = PetType.create!(color: colors(:red), species: species(:blumaroo),
		                            body_id: 2, created_at: Time.new(2010))
		PetState.create!(pet_type: pet_type2, mood_id: 1, female: true,
		                  swf_asset_ids: [0], labeled: true)

		get "/roulette.json?species=1"
		expect(JSON.parse(response.body)["species"]).to eq(species(:acara).id)

		get "/roulette.json?color=61"
		expect(JSON.parse(response.body)["color"]).to eq(colors(:red).id)

		get "/roulette.json?species=1&color=61" # There's no red acara.
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to eq("No showable pet found for Red Acara (color 61, species 1)")
	end

	it "accepts names as well as IDs, like the rest of the site" do
		get "/roulette.json?species=acara"
		expect(response).to have_http_status(:ok)
		expect(JSON.parse(response.body)["species"]).to eq(species(:acara).id)

		get "/roulette.json?color=blue"
		expect(response).to have_http_status(:ok)
		expect(JSON.parse(response.body)["color"]).to eq(colors(:blue).id)
	end

	it "400s on an unknown species or color" do
		get "/roulette.json?species=99"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to eq("Unknown species: 99")

		get "/roulette.json?color=99"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to eq("Unknown color: 99")

		get "/roulette.json?species=dragon" # No such name.
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to eq("Unknown species: dragon")

		get "/roulette.json?color=dragon"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to eq("Unknown color: dragon")
	end

	it "400s on an unknown zone or a bad count" do
		get "/roulette?zones=99"
		expect(response).to have_http_status(:bad_request)

		get "/roulette.json?zones=99"
		expect(JSON.parse(response.body)["error"]).to match(/Unknown zone/)

		get "/roulette.json?zones=hat"
		expect(response).to have_http_status(:bad_request)

		# Zone IDs start at one, so 0 is unknown too.
		get "/roulette.json?zones=0"
		expect(response).to have_http_status(:bad_request)

		# One bad ID fails the whole request, even with a good one.
		get "/roulette.json?zones=40,99"
		expect(response).to have_http_status(:bad_request)

		get "/roulette.json?count=abc"
		expect(response).to have_http_status(:bad_request)

		get "/roulette.json?count=-1"
		expect(response).to have_http_status(:bad_request)
	end

	it "gives friendly errors for junk numbers, rather than Ruby's" do
		get "/roulette.json?count=abc"
		expect(JSON.parse(response.body)["error"]).not_to match(/Integer\(\)/)
		expect(JSON.parse(response.body)["error"]).to match(/count/)
	end

	it "400s on more zones than exist" do
		ids = Array.new(Zone.count + 1, 40).join(",")

		get "/roulette.json?zones=#{ids}"
		expect(response).to have_http_status(:bad_request)
		expect(JSON.parse(response.body)["error"]).to match(/Too many zones/)
	end

	it "treats falsy full values as off" do
		restrict = Array.new(52, "0")
		Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(12).each_with_index do |zone, i|
			Item.create!(name: "Full #{i + 1}", description: "A test item",
			             thumbnail_url: "https://images.neopets.example/test.gif",
			             rarity: "NP", price: 100, weight_lbs: 1,
			             zones_restrict: restrict.join,
			             cached_compatible_body_ids: [1],
			             cached_occupied_zone_ids: [zone.id])
		end

		get "/roulette.json?full=0"
		expect(JSON.parse(response.body)["objects"].size).to be_between(3, 10)

		get "/roulette.json?full=false"
		expect(JSON.parse(response.body)["objects"].size).to be_between(3, 10)

		get "/roulette.json?full=no"
		expect(JSON.parse(response.body)["objects"].size).to be_between(3, 10)

		get "/roulette.json?full=1"
		expect(JSON.parse(response.body)["objects"].size).to eq(13)
	end

	it "doesn't let anyone cache a spin" do
		get "/roulette"

		expect(response.headers["Cache-Control"]).to match(/no-cache|no-store|max-age=0/)
	end

	it "doesn't hide unexpected ArgumentErrors as 400s" do
		allow(Roulette).to receive(:pick_item_ids).and_raise(ArgumentError, "a bug")

		expect { get "/roulette.json" }.to raise_error(ArgumentError, "a bug")
	end
end
