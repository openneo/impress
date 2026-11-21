require_relative '../rails_helper'

RSpec.describe "Item search", type: :request do
	before do
		Item.create!(name: "Jousting Helm", description: "A test helm",
		             thumbnail_url: "https://images.neopets.example/test.gif",
		             rarity: "Rare", rarity_index: 101, price: 100, weight_lbs: 1,
		             zones_restrict: "0" * 52)
	end

	it "redirects to the item when the search has exactly one result" do
		item = Item.find_by!(name: "Jousting Helm")

		get "/items", params: {q: "jousting"}

		expect(response).to redirect_to(item_path(item))
	end

	it "shows an empty page, not an error, for a page past the only result" do
		# The search's total count is still 1, but this page has no items, so
		# there's nothing to redirect to.
		get "/items", params: {q: "jousting", page: "3"}

		expect(response).to have_http_status(:ok)
	end
end
