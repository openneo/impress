require_relative '../rails_helper'

RSpec.describe AltStylesController, type: :controller do
	include Devise::Test::ControllerHelpers

	fixtures :colors, :species, :zones

	describe "GET #index as JSON" do
		before do
			AltStyle.create!(id: 87966, color: colors(:blue), species: species(:acara),
				body_id: 607, real_series_name: "Nostalgic",
				real_full_name: "Nostalgic Blue Acara",
				thumbnail_url: "https://images.neopets.com/items/token.gif")
		end

		it "names the species, so the wardrobe can match searches like \"nostalgic acara\"" do
			get :index, params: {species_id: species(:acara).id}, format: :json

			expect(response).to have_http_status(:ok)
			expect(response.parsed_body).to contain_exactly(
				a_hash_including(
					"id" => 87966,
					"adjective_name" => "Nostalgic Blue",
					"color" => a_hash_including("human_name" => "Blue"),
					"species" => a_hash_including(
						"id" => species(:acara).id,
						"human_name" => "Acara",
					),
				),
			)
		end
	end
end
