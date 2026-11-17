require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe Neopets::RainbowPool, type: :model do

	def stub_pool_request(body)
		stub_request(:post, "https://www.neopets.com/np-templates/ajax/pool/pool.php").
			with(
				headers: {
					"Content-Type": "application/x-www-form-urlencoded",
					"X-Requested-With": "XMLHttpRequest",
					"Cookie": "neologin=STUB_NEOLOGIN",
					"User-Agent": Rails.configuration.user_agent_for_neopets,
				},
				body:,
			)
	end

	def fixture(name)
		{ body: (Rails.root / "spec" / "fixtures" / "rainbow_pool" / name).read }
	end

	let!(:cookie) { NeologinCookie.create!(cookie: "STUB_NEOLOGIN") }
	before { allow(DiscordNotifier).to receive(:notify_neologin_failure) }

	describe ".load_all_pets" do
		subject(:all_pets) { Neopets::RainbowPool.load_all_pets }

		it "loads all species and colors" do
			stub_pool_request("mode=AllPets").to_return(fixture("all_pets.json"))

			expect(all_pets[:species].size).to eq 56
			expect(all_pets[:species].first).to eq({id: 1, name: "Acara"})
			expect(all_pets[:colors].size).to eq 120
			expect(all_pets[:colors]).to include({id: 121, name: "Birthday"})
		end

		it "raises if the lists are empty" do
			stub_pool_request("mode=AllPets").to_return(
				body: '{"success":true,"speciesList":[],"colors":[],"mode":"AllPets"}')
			expect { all_pets }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat)
		end
	end

	describe ".load_colors_for_species" do
		subject(:colors) { Neopets::RainbowPool.load_colors_for_species(1) }

		def stub_colors_request
			stub_pool_request("f_species_id=1&mode=getAllPetColors")
		end

		it "loads colors and image hashes for the species" do
			stub_colors_request.to_return(fixture("colors_acara.json"))

			expect(colors.size).to eq 77
			expect(colors.first).to eq(
				{color_id: 120, name: "25th Anniversary", image_hash: "g3m4n4sf"})
			expect(colors).to include(
				{color_id: 98, name: "ElderlyGir", image_hash: "5ohnvj99"})
		end

		it "raises if no colors are listed" do
			stub_colors_request.to_return(
				body: '{"success":true,"items":[],"mode":"getAllPetColors"}')
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /no colors/)
		end

		it "raises if an image URL looks different" do
			stub_colors_request.to_return(
				body: '{"success":true,"items":[{"id":8,"name":"Blue",' +
					'"image":"https://pets.neopets.com/cpn/mnbztxxn/1/7.png"}]}')
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /image URL/)
		end

		it "raises if a field is missing" do
			stub_colors_request.to_return(
				body: '{"success":true,"items":[{"name":"Blue",' +
					'"image":"//pets.neopets.com/cp/mnbztxxn/1/7.png"}]}')
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /id/)
		end

		it "raises if the response isn't JSON (like the old HTML page)" do
			stub_colors_request.to_return(body: "<html>Rainbow Pool!</html>")
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /wasn't JSON/)
		end

		it "raises if the response isn't successful" do
			stub_colors_request.to_return(body: '{"success":false}')
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /wasn't successful/)
		end

		it "raises CookieRejected for a login error" do
			stub_colors_request.to_return(
				body: '{"error":true,"errType":"login","errMsg":"Please log in"}')
			expect { colors }.to raise_error(Neologin::CookieRejected)
		end

		it "raises CookieRejected for a redirect to the login page" do
			stub_colors_request.to_return(status: 302,
				headers: {"Location": "/loginpage.phtml"})
			expect { colors }.to raise_error(Neologin::CookieRejected)
		end

		describe "tracking our cookie's health" do
			it "records a success, even if we can't parse the response" do
				stub_colors_request.to_return(body: "<html>Rainbow Pool!</html>")
				expect { colors }.to raise_error(
					Neopets::RainbowPool::UnexpectedResponseFormat)

				# A format change isn't the cookie's fault! And if we counted it, we'd
				# use up our one "the cookie failed" alert on it.
				cookie.reload
				expect(cookie.last_used_successfully_at).to be_present
				expect(cookie).not_to be_failing
				expect(cookie.notified_failure_at).to be_nil
				expect(DiscordNotifier).not_to have_received(:notify_neologin_failure)
			end

			it "records a failure when Neopets rejects the cookie" do
				stub_colors_request.to_return(
					body: '{"error":true,"errType":"login","errMsg":"Please log in"}')
				expect { colors }.to raise_error(Neologin::CookieRejected)

				expect(cookie.reload).to be_expired
				expect(DiscordNotifier).to have_received(:notify_neologin_failure)
			end
		end

		it "raises for other statuses" do
			stub_colors_request.to_return(status: 500)
			expect { colors }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /500/)
		end
	end

	describe ".load_brushes" do
		subject(:brushes) { Neopets::RainbowPool.load_brushes }

		it "loads paint brushes" do
			stub_pool_request("mode=Brushes").to_return(fixture("brushes.json"))

			expect(brushes.size).to eq 74
			expect(brushes).to include({
				item_id: 100585,
				color_id: 121,
				name: "Birthday Paint Brush",
				image_url: "https://images.neopets.com/items/f4b5d6b0.gif",
			})
		end

		it "raises if no brushes are listed" do
			stub_pool_request("mode=Brushes").to_return(
				body: '{"success":true,"brushes":[],"mode":"Brushes"}')
			expect { brushes }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /no paint brushes/)
		end

		it "raises if a brush is missing its color ID" do
			stub_pool_request("mode=Brushes").to_return(
				body: '{"success":true,"brushes":[{"oii":1,"colorId":null,' +
					'"name":"Mystery Paint Brush","image":"https://example.com/a.gif"}]}')
			expect { brushes }.to raise_error(
				Neopets::RainbowPool::UnexpectedResponseFormat, /colorId/)
		end
	end
end
