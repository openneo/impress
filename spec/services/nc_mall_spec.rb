require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Neopets::NCMall, type: :model do
	describe ".load_styles" do
		def stub_styles_request
			stub_request(:post, "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php").
				with(
					headers: {
						"Content-Type": "application/x-www-form-urlencoded",
						"X-Requested-With": "XMLHttpRequest",
						"Cookie": "neologin=STUB_NEOLOGIN"
					},
					body: "mode=getStyles&species=2&tab=1",
				)
		end

		subject(:styles) do
			Neopets::NCMall.load_styles(
				species_id: 2,
				neologin: "STUB_NEOLOGIN",
			)
		end

		it "loads current NC styles from the NC Mall" do
			stub_styles_request.to_return(
				body: '{"success":true,"styles":{"87966":{"oii":87966,"name":"Nostalgic Alien Aisha","image":"https:\/\/images.neopets.com\/items\/nostalgic_alien_aisha.gif","limited":false},"87481":{"oii":87481,"name":"Nostalgic Sponge Aisha","image":"https:\/\/images.neopets.com\/items\/nostalgic_sponge_aisha.gif","limited":false},"90031":{"oii":90031,"name":"Celebratory Anniversary Aisha","image":"https:\/\/images.neopets.com\/items\/624dc08bcf.gif","limited":true},"90050":{"oii":90050,"name":"Nostalgic Tyrannian Aisha","image":"https:\/\/images.neopets.com\/items\/b225e06541.gif","limited":true}}}',
			)

			expect(styles).to contain_exactly(
				{
					oii: 87481,
					name: "Nostalgic Sponge Aisha",
					image: "https://images.neopets.com/items/nostalgic_sponge_aisha.gif",
					limited: false,
				},
				{
					oii: 87966,
					name: "Nostalgic Alien Aisha",
					image: "https://images.neopets.com/items/nostalgic_alien_aisha.gif",
					limited: false,
				},
				{
					oii: 90031,
					name: "Celebratory Anniversary Aisha",
					image: "https://images.neopets.com/items/624dc08bcf.gif",
					limited: true,
				},
				{
					oii: 90050,
					name: "Nostalgic Tyrannian Aisha",
					image: "https://images.neopets.com/items/b225e06541.gif",
					limited: true,
				}
			)
		end

		it "raises an error if the request returns a non-200 status" do
			stub_styles_request.to_return(status: 400)

			expect { styles }.to raise_error(Neopets::NCMall::ResponseNotOK)
		end

		it "raises an error if the request returns a non-JSON response" do
			stub_styles_request.to_return(
				body: "Oops, this request failed for some weird reason!",
			)

			expect { styles }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end

		it "raises an error if the request returns unexpected JSON" do
			stub_styles_request.to_return(
				body: '{"success": false}',
			)

			expect { styles }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end
	end
end
