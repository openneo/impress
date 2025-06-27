require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe LebronNCValues, type: :model do
	describe ".find_by_name" do
		def stub_page_request
			stub_request(:get, "https://lebron-values.netlify.app/item_values.json").
				with(
					headers: {
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
				)
		end

		context "when loading" do
			before do
				stub_page_request.to_return(
					body: '{"10th birthday balloon garland": "-", "1 large neocola with ice": "1-2", "air faerie bubble necklace": "Permanent Buyable"}'
				)
			end

			context "a standard item value" do
				subject(:value) { LebronNCValues.find_by_name("1 Large Neocola with Ice") }
				it("loads value text as-is") { expect(value[:value_text]).to eq("1-2") }
			end

			context "a more complex item value" do
				subject(:value) { LebronNCValues.find_by_name("Air Faerie Bubble Necklace") }
				it("loads value text as-is") { expect(value[:value_text]).to eq("Permanent Buyable") }
			end

			context "a completely unknown item value" do
				subject(:value) { LebronNCValues.find_by_name("Floating Negg Faerie Doll") }
				it("raises NotFound") { expect { value }.to raise_error(LebronNCValues::NotFound) }
			end

			context "a known blank item value" do
				subject(:value) { LebronNCValues.find_by_name("10th Birthday Balloon Garland") }
				it("raises NotFound") { expect { value }.to raise_error(LebronNCValues::NotFound) }
			end
		end

		context "when the request fails" do
			before { stub_page_request.to_return(status: 404, body: "{}") }

			subject(:value) { LebronNCValues.find_by_name("1 Large Neocola with Ice") }
			it("raises NetworkError") { expect { value }.to raise_error(LebronNCValues::NetworkError) }
		end

		context "when the response is malformed" do
			before { stub_page_request.to_return(body: "Hello, world!") }

			subject(:value) { LebronNCValues.find_by_name("1 Large Neocola with Ice") }
			it("raises NetworkError") { expect { value }.to raise_error(LebronNCValues::NetworkError) }
		end

		context "when the request times out" do
			before { stub_page_request.to_timeout }

			subject(:value) { LebronNCValues.find_by_name("1 Large Neocola with Ice") }
			it("raises NetworkError") { expect { value }.to raise_error(LebronNCValues::NetworkError) }
		end

		context "when the request fails to connect" do
			before { stub_page_request.to_raise(Socket::ResolutionError) }

			subject(:value) { LebronNCValues.find_by_name("1 Large Neocola with Ice") }
			it("raises NetworkError") { expect { value }.to raise_error(LebronNCValues::NetworkError) }
		end
	end
end
