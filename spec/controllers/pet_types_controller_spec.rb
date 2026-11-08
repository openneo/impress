require_relative '../rails_helper'

RSpec.describe PetTypesController, type: :controller do
	include Devise::Test::ControllerHelpers

	fixtures :colors, :species, :pet_types

	describe "GET #show as JSON" do
		it "includes the image hash, for the homepage preview" do
			pet_types(:blue_acara).update!(basic_image_hash: "abc123")

			get :show, params: {species_id: 1, color_id: 8}, format: :json

			expect(response).to have_http_status(:ok)
			expect(response.parsed_body).to include(
				"id" => pet_types(:blue_acara).id,
				"image_hash" => "abc123",
			)
		end

		it "returns 404 for a pet type we haven't seen" do
			expect {
				get :show, params: {species_id: 1, color_id: 999}, format: :json
			}.to raise_error(ActiveRecord::RecordNotFound)
		end
	end
end
