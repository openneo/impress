require_relative '../rails_helper'

RSpec.describe "The item sources page", type: :request do
	fixtures :colors, :species, :pet_types

	def create_pb_item(name)
		Item.create!(name:, description: Item::PAINTBRUSH_SET_DESCRIPTION,
		             thumbnail_url: "https://images.neopets.example/test.gif",
		             rarity: "Rare", rarity_index: 101, price: 0, weight_lbs: 1,
		             zones_restrict: "0" * 52)
	end

	it "groups PB items by color, even when some match no color" do
		# One item matches the Maraquan color; the other matches no color at all,
		# so it lands in the "Basic colors" group, keyed by `nil`. Sorting those
		# groups used to compare nil with a color name, and crash.
		colors(:maraquan).update!(pb_item_name: "Maraquan Paint Brush",
		                          pb_item_thumbnail_url: "https://images.neopets.example/mpb.gif")
		maraquan_item = create_pb_item("Maraquan Acara Hat")
		basic_item = create_pb_item("Mystery Acara Hat")

		get "/items/sources/#{maraquan_item.id},#{basic_item.id}"

		expect(response).to have_http_status(:ok)
		expect(response.body).to include("Basic colors")
		expect(response.body).to include("Maraquan Paint Brush")
		expect(response.body.index("Basic colors")).
			to be < response.body.index("Maraquan Paint Brush")
	end
end
