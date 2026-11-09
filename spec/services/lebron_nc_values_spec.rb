require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe LebronNCValues, type: :model do
	include ActiveSupport::Testing::TimeHelpers

	# The values are memoized per-process, so don't let that leak between examples.
	before { LebronNCValues.reset_in_memory_values! }
	after { LebronNCValues.reset_in_memory_values! }

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

		context "when looking up repeatedly" do
			let(:body) { '{"1 large neocola with ice": "1-2"}' }
			let(:cache) { ActiveSupport::Cache::MemoryStore.new }

			before do
				allow(Rails).to receive(:cache).and_return(cache)
				stub_page_request.to_return(body: body)
			end

			it "reuses the in-memory values within the TTL, without touching the cache or network" do
				LebronNCValues.find_by_name("1 Large Neocola with Ice")

				expect(cache).not_to receive(:fetch)
				travel(LebronNCValues::IN_MEMORY_TTL - 1.minute) do
					expect(LebronNCValues.find_by_name("1 Large Neocola with Ice")[:value_text]).to eq("1-2")
				end
				expect(a_request(:get, "https://lebron-values.netlify.app/item_values.json")).to have_been_made.once
			end

			it "reloads from the cache after the TTL, without re-fetching from the network" do
				LebronNCValues.find_by_name("1 Large Neocola with Ice")

				expect(cache).to receive(:fetch).and_call_original
				travel(LebronNCValues::IN_MEMORY_TTL + 1.minute) do
					expect(LebronNCValues.find_by_name("1 Large Neocola with Ice")[:value_text]).to eq("1-2")
				end
				expect(a_request(:get, "https://lebron-values.netlify.app/item_values.json")).to have_been_made.once
			end

			it "picks up fresh values once both the TTL and the cache have expired" do
				LebronNCValues.find_by_name("1 Large Neocola with Ice")
				stub_page_request.to_return(body: '{"1 large neocola with ice": "3-4"}')

				travel(LebronNCValues::IN_MEMORY_TTL + 1.minute) do
					cache.clear
					expect(LebronNCValues.find_by_name("1 Large Neocola with Ice")[:value_text]).to eq("3-4")
				end
			end

			it "doesn't memoize a failed load, so a later call can retry" do
				stub_page_request.to_return(status: 500, body: "{}").then.to_return(body: body)

				expect { LebronNCValues.find_by_name("1 Large Neocola with Ice") }.
					to raise_error(LebronNCValues::NetworkError)
				expect(LebronNCValues.instance_variable_get(:@memoized)).to be_nil
				expect(LebronNCValues.find_by_name("1 Large Neocola with Ice")[:value_text]).to eq("1-2")
			end

			it "keeps the old values if a refresh after the TTL fails, and retries next time" do
				LebronNCValues.find_by_name("1 Large Neocola with Ice")
				stub_page_request.to_return(status: 500, body: "{}").then.to_return(body: '{"1 large neocola with ice": "3-4"}')

				travel(LebronNCValues::IN_MEMORY_TTL + 1.minute) do
					cache.clear
					expect { LebronNCValues.find_by_name("1 Large Neocola with Ice") }.
						to raise_error(LebronNCValues::NetworkError)
					expect(LebronNCValues.find_by_name("1 Large Neocola with Ice")[:value_text]).to eq("3-4")
				end
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
