require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe Neopets::NCMall, type: :model do
	describe ".load_page" do
		def stub_page_request
			stub_request(:get, "https://ncmall.neopets.com/mall/ajax/load_page.phtml?type=new&cat=52&lang=en").
				with(
					headers: {
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
				)
		end

		subject(:page) do
			Neopets::NCMall.load_page("new", 52)
		end

		it "loads a page from the NC Mall" do
			stub_page_request.to_return(
				body: '{"html":"","render_html":"0","render":[82936,90226],"object_data":{"82936":{"id":82936,"name":"+1 Extra Pet Slot","description":"Just ONE more Neopet... just ONE more...! This pack includes 1 extra pet slot. Each extra pet slot can be used to create a new pet, adopt a pet, or bring back any idle pets lost from non-premium accounts.","price":500,"discountPrice":0,"atPurchaseDiscountPrice":null,"discountBegin":1735372800,"discountEnd":1735718399,"uses":1,"isSuperpack":0,"isBundle":0,"packContents":null,"isAvailable":1,"imageFile":"mall_petslots_1","saleBegin":1703094300,"saleEnd":0,"duration":0,"isSoldOut":0,"isNeohome":0,"isWearable":0,"isBuyable":1,"isAlbumTheme":0,"isGiftbox":0,"isInRandomWindow":null,"isElite":0,"isCollectible":0,"isKeyquest":0,"categories":null,"isHabitarium":0,"isNoInvInsert":1,"isLimitedQuantity":0,"isPresale":0,"isGambling":0,"petSlotPack":1,"maxPetSlots":10,"currentUserBoughtPetSlots":0,"formatted":{"name":"+1 Extra Pet Slot","ck":false,"price":"500","discountPrice":"0","limited":false},"converted":true},"90226":{"id":90226,"name":"Weekend Sales 2025 Mega Gram","description":"Lets go shopping! Purchase this Weekend Sales Mega Gram and choose from exclusive Weekend Sales items to send to a Neofriend, no gift box needed! This gram also has a chance of including a Limited Edition NC item. Please visit the NC Mall FAQs for more information on this item.","price":250,"discountPrice":125,"atPurchaseDiscountPrice":null,"discountBegin":1737136800,"discountEnd":1737446399,"uses":1,"isSuperpack":0,"isBundle":0,"packContents":null,"isAvailable":1,"imageFile":"42embjc204","saleBegin":1737136800,"saleEnd":1739865599,"duration":0,"isSoldOut":0,"isNeohome":0,"isWearable":0,"isBuyable":1,"isAlbumTheme":0,"isGiftbox":0,"isInRandomWindow":null,"isElite":0,"isCollectible":0,"isKeyquest":0,"categories":null,"isHabitarium":0,"isNoInvInsert":0,"isLimitedQuantity":0,"isPresale":0,"isGambling":0,"formatted":{"name":"Weekend Sales 2025 Mega Gram","ck":false,"price":"250","discountPrice":"125","limited":false},"converted":true}},"response":{"category":"52","type":"new","image":{"location":"//images.neopets.com/items/","star_location":"//images.neopets.com/ncmall/","extension":".gif","stars":{"blue":"star_blue","red":"star_red","orange":"star_orange","leso":"leso_star"}},"heading":"New","no_items_msg":"","shopkeeper":{"img":"//images.neopets.com/ncmall/shopkeepers/mall_new.jpg","title":"Style is all about what\'s new…  good thing that\'s all I stock!","message":"Come browse my shop and find the latest and greatest the NC Mall has to offer!","new_format":true},"strings":{"claim_it":"Claim it","none_left":"Sorry, there are none left!","nc":"NC","free":"FREE","add_to_cart":"Add to cart"}}}'
			)

			expect(page[:items]).to contain_exactly(
				{
					id: 82936,
					name: "+1 Extra Pet Slot",
					description: "Just ONE more Neopet... just ONE more...! This pack includes 1 extra pet slot. Each extra pet slot can be used to create a new pet, adopt a pet, or bring back any idle pets lost from non-premium accounts.",
					price: 500,
					discount: nil,
					is_available: true,
				},
				{
					id: 90226,
					name: "Weekend Sales 2025 Mega Gram",
					description: "Lets go shopping! Purchase this Weekend Sales Mega Gram and choose from exclusive Weekend Sales items to send to a Neofriend, no gift box needed! This gram also has a chance of including a Limited Edition NC item. Please visit the NC Mall FAQs for more information on this item.",
					price: 250,
					discount: {
						price: 125,
						begins_at: Time.find_zone("Pacific Time (US & Canada)").
							local(2025, 1, 17, 10),
						ends_at: Time.find_zone("Pacific Time (US & Canada)").
							local(2025, 1, 20, 23, 59, 59),
					},
					is_available: true,
				},
			)
		end
	end

	describe ".load_styles" do
		def stub_styles_request(tab:)
			stub_request(:post, "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php").
				with(
					headers: {
						"Content-Type": "application/x-www-form-urlencoded",
						"X-Requested-With": "XMLHttpRequest",
						"Cookie": "neologin=STUB_NEOLOGIN",
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
					body: "mode=getStyles&species=2&tab=#{tab}",
				)
		end

		def empty_styles_response
			# You'd think styles would be `{}` in this case, but it's `[]`. Huh!
			{ body: '{"success":true,"styles":[]}' }
		end

		subject(:styles) do
			Neopets::NCMall.load_styles(
				species_id: 2,
				neologin: "STUB_NEOLOGIN",
			)
		end

		it "loads current NC styles from the NC Mall" do
			stub_styles_request(tab: 1).to_return(
				body: '{"success":true,"styles":{"87966":{"oii":87966,"name":"Nostalgic Alien Aisha","image":"https:\/\/images.neopets.com\/items\/nostalgic_alien_aisha.gif","limited":false},"87481":{"oii":87481,"name":"Nostalgic Sponge Aisha","image":"https:\/\/images.neopets.com\/items\/nostalgic_sponge_aisha.gif","limited":false},"90031":{"oii":90031,"name":"Celebratory Anniversary Aisha","image":"https:\/\/images.neopets.com\/items\/624dc08bcf.gif","limited":true},"90050":{"oii":90050,"name":"Nostalgic Tyrannian Aisha","image":"https:\/\/images.neopets.com\/items\/b225e06541.gif","limited":true}}}',
			)
			stub_styles_request(tab: 2).to_return(
				body: '{"success":true,"styles":{"90338":{"oii":90338,"name":"Prismatic Pine: Christmas Aisha","image":"https:\/\/images.neopets.com\/items\/3m182ff5.gif","limited":true,"style":90252},"90348":{"oii":90348,"name":"Prismatic Tinsel: Christmas Aisha","image":"https:\/\/images.neopets.com\/items\/4j29mb91.gif","limited":true,"style":90252}}}'
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
				},
				{
					oii: 90338,
					name: "Prismatic Pine: Christmas Aisha",
					image: "https://images.neopets.com/items/3m182ff5.gif",
					limited: true,
				},
				{
					oii: 90348,
					name: "Prismatic Tinsel: Christmas Aisha",
					image: "https://images.neopets.com/items/4j29mb91.gif",
					limited: true,
				}
			)
		end

		it "handles the NC Mall's odd API behavior for zero styles" do
			stub_styles_request(tab: 1).to_return(empty_styles_response)
			stub_styles_request(tab: 2).to_return(empty_styles_response)

			expect(styles).to be_empty
		end

		it "raises an error if the request returns a non-200 status" do
			stub_styles_request(tab: 1).to_return(status: 400)
			stub_styles_request(tab: 2).to_return(empty_styles_response)

			expect { styles }.to raise_error(Neopets::NCMall::ResponseNotOK)
		end

		it "raises an error if the request returns a non-JSON response" do
			stub_styles_request(tab: 1).to_return(
				body: "Oops, this request failed for some weird reason!",
			)
			stub_styles_request(tab: 2).to_return(empty_styles_response)

			expect { styles }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end

		it "raises an error if the request returns unexpected JSON" do
			stub_styles_request(tab: 1).to_return(
				body: '{"success": false}',
			)
			stub_styles_request(tab: 2).to_return(empty_styles_response)

			expect { styles }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end
	end
end
