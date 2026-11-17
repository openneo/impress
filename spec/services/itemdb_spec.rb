require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe Itemdb, type: :model do
	include ActiveSupport::Testing::TimeHelpers

	around do |example|
		old_key = ENV["ITEMDB_API_KEY"]
		ENV["ITEMDB_API_KEY"] = "test-key"
		Itemdb.reset_token!
		example.run
	ensure
		ENV["ITEMDB_API_KEY"] = old_key
		Itemdb.reset_token!
	end

	# We trade our API key for a short-lived token before each API request.
	def stub_token_request
		stub_request(:post, "https://itemdb.com.br/api/auth/token").
			with(headers: {"X-Itemdb-Key": "test-key"})
	end
	before { stub_token_request.to_return(body: '{"token":"test-token"}') }

	def item_data(id, name, description: "")
		{
			"internal_id" => id - 20000,
			"item_id" => id,
			"name" => name,
			"slug" => name.parameterize,
			"image" => {
				"url" => "https://images.neopets.com/items/#{name.parameterize}.gif",
				"id" => name.parameterize,
			},
			"type" => "nc",
			"description" => description,
			"status" => "active",
		}
	end

	describe ".load_style_tokens" do
		def stub_list_request(page: 1)
			stub_request(:get,
				"https://itemdb.com.br/api/v2/lists/official/1037/itemdata").
				with(
					query: {intent: "minimal", page: page.to_s},
					headers: {"X-Itemdb-Token": "test-token"},
				)
		end

		it "loads the whole list, keyed by Neopets item ID" do
			stub_list_request.to_return(
				headers: {"x-itemdb-has-next-page" => "false"},
				body: [
					item_data(100684, "Blended Burlap Acara"),
					item_data(100685, "Blended Burlap Aisha", description: "So cozy!"),
				].to_json,
			)

			tokens = Itemdb.load_style_tokens

			expect(tokens.keys).to eq [100684, 100685]
			expect(tokens[100684]).to have_attributes(
				id: 100684,
				name: "Blended Burlap Acara",
				thumbnail_url:
					"https://images.neopets.com/items/blended-burlap-acara.gif",
				description: nil,
				slug: "blended-burlap-acara",
			)
			expect(tokens[100685].description).to eq "So cozy!"
		end

		it "follows pagination, if the list outgrows one page" do
			stub_list_request(page: 1).to_return(
				headers: {"x-itemdb-has-next-page" => "true"},
				body: [item_data(100684, "Blended Burlap Acara")].to_json,
			)
			stub_list_request(page: 2).to_return(
				headers: {"x-itemdb-has-next-page" => "false"},
				body: [item_data(100685, "Blended Burlap Aisha")].to_json,
			)

			expect(Itemdb.load_style_tokens.keys).to eq [100684, 100685]
		end

		it "skips items that have no Neopets item ID" do
			stub_list_request.to_return(body: [
				item_data(100684, "Blended Burlap Acara"),
				item_data(100685, "Mystery Token").merge("item_id" => nil),
			].to_json)

			expect(Itemdb.load_style_tokens.keys).to eq [100684]
		end

		it "raises NetworkError when the API key is rejected" do
			stub_token_request.to_return(
				status: 401, body: '{"error":"Invalid API key"}')

			expect { Itemdb.load_style_tokens }.to raise_error(
				Itemdb::NetworkError, /status code 401.*auth\/token/)
		end

		it "reuses its token, until it's close to expiring" do
			token_request = stub_token_request.
				to_return(body: '{"token":"test-token"}')
			stub_list_request.to_return(body: "[]")

			Itemdb.load_style_tokens
			travel(40.minutes) { Itemdb.load_style_tokens }
			expect(token_request).to have_been_requested.once

			travel(55.minutes) { Itemdb.load_style_tokens }
			expect(token_request).to have_been_requested.twice
		end

		it "raises NetworkError when the response isn't a list of items" do
			stub_list_request.to_return(body: '{"error":"List not found"}')

			expect { Itemdb.load_style_tokens }.to raise_error(
				Itemdb::NetworkError, /unexpected data/)
		end

		it "raises NotConfigured when there's no API key" do
			ENV["ITEMDB_API_KEY"] = nil
			expect { Itemdb.load_style_tokens }.
				to raise_error(Itemdb::NotConfigured)
		end
	end

	describe ".load_items" do
		def stub_items_request(item_ids)
			stub_request(:post, "https://itemdb.com.br/api/v2/items/many").
				with(
					body: {type: "item_id", data: item_ids, intent: "minimal"}.to_json,
					headers: {
						"Content-Type": "application/json",
						"X-Itemdb-Token": "test-token",
					},
				)
		end

		it "loads items by ID, omitting ones itemdb doesn't know" do
			stub_items_request([100684, 100685]).to_return(body: {
				"100684" => item_data(100684, "Blended Burlap Acara"),
			}.to_json)

			items = Itemdb.load_items([100684, 100685])

			expect(items.keys).to eq [100684]
			expect(items[100684].name).to eq "Blended Burlap Acara"
		end

		it "splits large lookups into batches" do
			ids = (1..101).to_a
			first = stub_items_request(ids.first(100)).to_return(body: "{}")
			second = stub_items_request([101]).to_return(body: "{}")

			expect(Itemdb.load_items(ids)).to eq({})
			expect(first).to have_been_requested
			expect(second).to have_been_requested
		end

		it "makes no requests for an empty lookup" do
			expect(Itemdb.load_items([])).to eq({})
		end
	end
end
