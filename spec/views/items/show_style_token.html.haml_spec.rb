require_relative '../../rails_helper'

RSpec.describe "items/show_style_token", type: :view do
	fixtures :colors, :species, :zones

	before do
		# Shared partials like the outfit viewer live in `application/`, which
		# controllers search automatically, but view specs don't.
		view.lookup_context.prefixes << "application"

		# Serve a simple manifest for the style's layer, with just a PNG.
		allow(NeopetsMediaArchive).to receive(:load_file).and_return({
			content: {cpmanifest: {assets: [{asset_data: [
				{file_ext: "png", url: "cp/bio/data/64362.png"},
			]}]}}.to_json,
			source: "network",
		})

		# The item header looks up the NC trade value. Let's say there isn't one.
		allow(LebronNCValues).to receive(:find_by_name).
			and_raise(LebronNCValues::NotFound)

		# The Devise helpers aren't available in view specs, so we stub them.
		without_partial_double_verification do
			allow(view).to receive(:user_signed_in?).and_return(false)
			allow(view).to receive(:support_staff?).and_return(false)
		end
	end

	def create_alt_style
		swf_asset = SwfAsset.create!(type: "biology", remote_id: 64362,
			url: "https://images.neopets.com/64362.swf",
			zone: zones(:background), body_id: 607, zones_restrict: "",
			manifest_url: "https://images.neopets.com/manifest.json")
		AltStyle.create!(id: 87966, color: colors(:blue), species: species(:acara),
			body_id: 607, swf_assets: [swf_asset], real_series_name: "Nostalgic",
			real_full_name: "Nostalgic Blue Acara",
			thumbnail_url: "https://images.neopets.com/items/token.gif")
	end

	def render_for(alt_style)
		item = alt_style.token_item
		assign(:item, item)
		assign(:alt_style, alt_style)
		assign(:preview_outfit, Outfit.new(alt_style:))
		assign(:trades, {offering: [], seeking: []})
		render
	end

	it "shows the style's layers, instead of a pet wearing the item" do
		render_for create_alt_style

		expect(rendered).to include("cp/bio/data/64362.png")
		expect(rendered).not_to include("species-face-picker")
	end

	it "describes the token, since we don't know its real description" do
		render_for create_alt_style

		expect(rendered).to include(
			"This token unlocks the Nostalgic Blue style for your Acara.")
	end

	it "prefers the real description, if we have one" do
		alt_style = create_alt_style
		alt_style.token_item.update!(description: "So retro!")
		render_for alt_style

		expect(rendered).to include("So retro!")
		expect(rendered).not_to include("This token unlocks")
	end

	it "links to the style in the wardrobe, and to related styles" do
		alt_style = create_alt_style
		render_for alt_style

		expect(rendered).to include(CGI.escapeHTML(view.wardrobe_path(
			species: alt_style.species_id, color: alt_style.color_id,
			style: alt_style.id)))
		expect(rendered).to include("All Acara styles")
		expect(rendered).to include("All Nostalgic styles")
	end
end
