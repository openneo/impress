require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe Neopets::NCMall, type: :model do
	describe ".load_page" do
		def stub_v2_page_request(page: 1)
			stub_request(:get, "https://ncmall.neopets.com/mall/ajax/v2/category/index.phtml?type=new_items&cat=52&page=#{page}&limit=24").
				with(
					headers: {
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
				)
		end

		subject(:page) do
			Neopets::NCMall.load_page("new_items", 52, page: 1, limit: 24)
		end

		it "loads a page from the v2 NC Mall API" do
			stub_v2_page_request.to_return(
				body: '{"html":"","render_html":"0","type":"new_items","data":[{"id":82936,"name":"+1 Extra Pet Slot","description":"Just ONE more Neopet... just ONE more...! This pack includes 1 extra pet slot. Each extra pet slot can be used to create a new pet, adopt a pet, or bring back any idle pets lost from non-premium accounts.","price":500,"discountPrice":0,"atPurchaseDiscountPrice":null,"discountBegin":1735372800,"discountEnd":1735718399,"uses":1,"isSuperpack":0,"isBundle":0,"packContents":null,"isAvailable":1,"imageFile":"mall_petslots_1","saleBegin":1703094300,"saleEnd":0,"duration":0,"isSoldOut":0,"isNeohome":0,"isWearable":0,"isBuyable":1,"isAlbumTheme":0,"isGiftbox":0,"isInRandomWindow":null,"isElite":0,"isCollectible":0,"isKeyquest":0,"categories":null,"isHabitarium":0,"isNoInvInsert":1,"isLimitedQuantity":0,"isPresale":0,"isGambling":0,"petSlotPack":1,"maxPetSlots":10,"currentUserBoughtPetSlots":0,"formatted":{"name":"+1 Extra Pet Slot","ck":false,"price":"500","discountPrice":"0","limited":false},"converted":true},{"id":90226,"name":"Weekend Sales 2025 Mega Gram","description":"Lets go shopping! Purchase this Weekend Sales Mega Gram and choose from exclusive Weekend Sales items to send to a Neofriend, no gift box needed! This gram also has a chance of including a Limited Edition NC item. Please visit the NC Mall FAQs for more information on this item.","price":250,"discountPrice":125,"atPurchaseDiscountPrice":null,"discountBegin":1737136800,"discountEnd":1737446399,"uses":1,"isSuperpack":0,"isBundle":0,"packContents":null,"isAvailable":1,"imageFile":"42embjc204","saleBegin":1737136800,"saleEnd":1739865599,"duration":0,"isSoldOut":0,"isNeohome":0,"isWearable":0,"isBuyable":1,"isAlbumTheme":0,"isGiftbox":0,"isInRandomWindow":null,"isElite":0,"isCollectible":0,"isKeyquest":0,"categories":null,"isHabitarium":0,"isNoInvInsert":0,"isLimitedQuantity":0,"isPresale":0,"isGambling":0,"formatted":{"name":"Weekend Sales 2025 Mega Gram","ck":false,"price":"250","discountPrice":"125","limited":false},"converted":true}],"totalItems":"2","totalPages":"1","page":"1","limit":"24"}'
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
			expect(page[:total_pages]).to eq(1)
			expect(page[:page]).to eq(1)
		end

		it "handles pagination metadata" do
			stub_v2_page_request.to_return(
				body: '{"html":"","render_html":"0","type":"new_items","data":[{"id":82936,"name":"Test Item","description":"Test","price":100,"discountPrice":0,"atPurchaseDiscountPrice":null,"discountBegin":1735372800,"discountEnd":1735718399,"uses":1,"isSuperpack":0,"isBundle":0,"packContents":null,"isAvailable":1,"imageFile":"test","saleBegin":1703094300,"saleEnd":0,"duration":0,"isSoldOut":0,"isNeohome":0,"isWearable":1,"isBuyable":1,"isAlbumTheme":0,"isGiftbox":0,"isInRandomWindow":null,"isElite":0,"isCollectible":0,"isKeyquest":0,"categories":null,"isHabitarium":0,"isNoInvInsert":0,"isLimitedQuantity":0,"isPresale":0,"isGambling":0,"formatted":{"name":"Test Item","ck":false,"price":"100","discountPrice":"0","limited":false},"converted":true}],"totalItems":"50","totalPages":"3","page":"1","limit":"24"}'
			)

			expect(page[:total_pages]).to eq(3)
			expect(page[:page]).to eq(1)
			expect(page[:limit]).to eq(24)
		end
	end

	describe ".load_categories" do
		def stub_homepage_request
			stub_request(:get, "https://ncmall.neopets.com/mall/shop.phtml").
				with(
					headers: {
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
				)
		end

		subject(:categories) do
			Neopets::NCMall.load_categories
		end

		it "extracts browsable categories from menu JSON and maps load types" do
			stub_homepage_request.to_return(
				body: '<html><head><script>window.ncmall_menu = [{"cat_id":52,"cat_name":"New","load_type":"new"},{"cat_id":54,"cat_name":"Popular","load_type":"popular"},{"cat_id":42,"cat_name":"Customization","load_type":"neopet","children":[{"cat_id":43,"cat_name":"Clothing","parent_id":42},{"cat_id":44,"cat_name":"Shoes","parent_id":42}]},{"cat_name":"Specialty","children":[{"cat_id":85,"cat_name":"NC Collectible","load_type":"collectible","url":"https://www.neopets.com/mall/nc_collectible_case.phtml"},{"cat_id":13,"cat_name":"Elite Boutique","url":"https://ncmall.neopets.com/mall/shop.phtml?page=&cat=13"}]}];</script></head></html>'
			)

			expect(categories).to contain_exactly(
				hash_including("cat_id" => 52, "cat_name" => "New", "type" => "new_items"),
				hash_including("cat_id" => 54, "cat_name" => "Popular", "type" => "popular_items"),
				hash_including("cat_id" => 42, "cat_name" => "Customization", "type" => "browse"),
				hash_including("cat_id" => 43, "cat_name" => "Clothing", "parent_id" => 42, "type" => "browse"),
				hash_including("cat_id" => 44, "cat_name" => "Shoes", "parent_id" => 42, "type" => "browse"),
			)

			# Should NOT include load_type field (it's been converted to type)
			categories.each do |cat|
				expect(cat).not_to have_key("load_type")
			end

			# Should NOT include categories with external URLs
			expect(categories).not_to include(
				hash_including("cat_name" => "NC Collectible"),
			)
			expect(categories).not_to include(
				hash_including("cat_name" => "Elite Boutique"),
			)

			# Should NOT include structural parent without cat_id
			expect(categories).not_to include(
				hash_including("cat_name" => "Specialty"),
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
					body: "mode=getAvailable&species=2&tab=#{tab}",
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

	describe ".load_exclusives" do
		def stub_exclusives_request
			stub_request(:post, "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php").
				with(
					headers: {
						"Content-Type": "application/x-www-form-urlencoded",
						"X-Requested-With": "XMLHttpRequest",
						"Cookie": "neologin=STUB_NEOLOGIN",
						"User-Agent": Rails.configuration.user_agent_for_neopets,
					},
					body: "key=StylingStudioTab&mode=getTab&tab=3&value=3",
				)
		end

		subject(:exclusives) do
			Neopets::NCMall.load_exclusives(neologin: "STUB_NEOLOGIN")
		end

		it "loads exclusive styles from tab 3" do
			stub_exclusives_request.to_return(
				body: '{"success":true,"exclusives":{"95639":{"name":"Treasured Roberta","image":"https:\/\/images.neopets.com\/items\/1c2h6d7fdn.gif","oii":95639},"95640":{"name":"Treasured Lisha","image":"https:\/\/images.neopets.com\/items\/0ocf7m2daj.gif","oii":95640}},"styleMeter":{"num":0,"max":15,"isReady":false},"mode":"getTab"}'
			)

			expect(exclusives).to contain_exactly(
				{
					oii: 95639,
					name: "Treasured Roberta",
					image: "https://images.neopets.com/items/1c2h6d7fdn.gif",
				},
				{
					oii: 95640,
					name: "Treasured Lisha",
					image: "https://images.neopets.com/items/0ocf7m2daj.gif",
				},
			)
		end

		it "handles empty exclusives" do
			stub_exclusives_request.to_return(
				body: '{"success":true,"exclusives":[],"styleMeter":{"num":0,"max":15,"isReady":false},"mode":"getTab"}'
			)

			expect(exclusives).to be_empty
		end

		it "raises an error if the request returns a non-200 status" do
			stub_exclusives_request.to_return(status: 400)

			expect { exclusives }.to raise_error(Neopets::NCMall::ResponseNotOK)
		end

		it "raises an error if the request returns a non-JSON response" do
			stub_exclusives_request.to_return(
				body: "Oops, this request failed for some weird reason!",
			)

			expect { exclusives }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end

		it "raises an error if the request returns unexpected JSON" do
			stub_exclusives_request.to_return(
				body: '{"success": false}',
			)

			expect { exclusives }.to raise_error(Neopets::NCMall::UnexpectedResponseFormat)
		end
	end
end
