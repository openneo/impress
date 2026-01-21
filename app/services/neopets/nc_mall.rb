require "addressable/template"

# Neopets::NCMall integrates with the Neopets NC Mall to fetch currently
# available items and their pricing.
#
# The integration works in two steps:
#
# 1. Category Discovery: We fetch the NC Mall homepage and extract the
#    browsable categories from the embedded `window.ncmall_menu` JSON data.
#    We filter out special feature categories (those with external URLs) and
#    structural parent nodes (those without a cat_id).
#
# 2. Item Fetching: For each category, we call the v2 category API with
#    pagination support. Large categories may span multiple pages, which we
#    fetch in parallel and combine. Items can appear in multiple categories,
#    so the rake task de-duplicates by item ID.
#
# The parsed item data includes:
#   - id: Neopets item ID
#   - name: Item display name
#   - description: Item description
#   - price: Regular price in NC (NeoCash)
#   - discount: Optional discount info (price, begins_at, ends_at)
#   - is_available: Whether the item is currently purchasable
#
# This module is used by the `neopets:import:nc_mall` rake task to sync our
# NCMallRecord table with the live NC Mall.
module Neopets::NCMall
	# Load the NC Mall page for a specific type and category ID, with pagination.
	CATEGORY_PAGE_URL_TEMPLATE = Addressable::Template.new(
		"https://ncmall.neopets.com/mall/ajax/v2/category/index.phtml{?type,cat,page,limit}"
	)
	def self.load_page(type, cat, page: 1, limit: 24)
		url = CATEGORY_PAGE_URL_TEMPLATE.expand(type:, cat:, page:, limit:)
		Sync do
			DTIRequests.get(url) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{url})"
				end

				parse_nc_page response.read
			end
		end
	end

	# Load all pages for a specific category.
	def self.load_category_all_pages(type, cat, limit: 24)
		# First, load page 1 to get total page count
		first_page = load_page(type, cat, page: 1, limit:)
		total_pages = first_page[:total_pages]

		# If there's only one page, return it
		return first_page[:items] if total_pages <= 1

		# Otherwise, load remaining pages in parallel
		Sync do
			remaining_page_tasks = (2..total_pages).map do |page_num|
				Async { load_page(type, cat, page: page_num, limit:) }
			end

			all_pages = [first_page] + remaining_page_tasks.map(&:wait)
			all_pages.flat_map { |page| page[:items] }
		end
	end

	# Load the NC Mall root document HTML, and extract categories from the
	# embedded menu JSON.
	ROOT_DOCUMENT_URL = "https://ncmall.neopets.com/mall/shop.phtml"
	MENU_JSON_PATTERN = /window\.ncmall_menu = (\[.*?\]);/m
	def self.load_categories
		html = Sync do
			DTIRequests.get(ROOT_DOCUMENT_URL) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{ROOT_DOCUMENT_URL})"
				end

				response.read
			end
		end

		# Extract the ncmall_menu JSON from the script tag
		match = html.match(MENU_JSON_PATTERN)
		unless match
			raise UnexpectedResponseFormat,
				"could not find window.ncmall_menu in homepage HTML"
		end

		begin
			menu = JSON.parse(match[1])
		rescue JSON::ParserError => e
			Rails.logger.debug "Failed to parse ncmall_menu JSON: #{e.message}"
			raise UnexpectedResponseFormat,
				"failed to parse ncmall_menu as JSON"
		end

		# Flatten the menu structure, and filter to browsable categories
		browsable_categories = flatten_categories(menu).
			# Skip categories without a cat_id (structural parent nodes)
			reject { |cat| cat['cat_id'].blank? }.
			# Skip categories with external URLs (special features)
			reject { |cat| cat['url'].present? }

		# Map each category to include the API type (and remove load_type)
		browsable_categories.map do |cat|
			cat.except("load_type").merge(
				"type" => map_load_type_to_api_type(cat["load_type"])
			)
		end
	end

	def self.load_styles(species_id:, neologin:)
		Sync do
			tabs = [
				Async { load_styles_tab(species_id:, neologin:, tab: 1) },
				Async { load_styles_tab(species_id:, neologin:, tab: 2) },
			]
			tabs.map(&:wait).flatten(1)
		end
	end

	# Generate a new image hash for a pet wearing specific items. Takes a base
	# pet sci (species/color image hash) and optional item IDs, and returns a
	# response containing the combined image hash in the :newsci field.
	# Use the returned hash with Neopets::CustomPets.fetch_viewer_data("@#{newsci}")
	# to get the full appearance data.
	PET_DATA_URL = "https://ncmall.neopets.com/mall/ajax/petview/getPetData.php"
	def self.fetch_pet_data_sci(pet_sci, item_ids = [])
		Sync do
			params = {"selPetsci" => pet_sci}
			item_ids.each { |id| params["itemsList[]"] = id.to_s }

			DTIRequests.post(
				PET_DATA_URL,
				[["Content-Type", "application/x-www-form-urlencoded"]],
				params.to_query,
			) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{PET_DATA_URL})"
				end

				begin
					data = JSON.parse(response.read)
				rescue JSON::ParserError
					raise UnexpectedResponseFormat,
						"failed to parse pet data response as JSON"
				end

				unless data["newsci"].is_a?(String) && data["newsci"].present?
					raise UnexpectedResponseFormat,
						"missing or invalid field newsci in pet data response"
				end

				data["newsci"]
			end
		end
	end

	private

	# Map load_type from menu JSON to the v2 API type parameter.
	def self.map_load_type_to_api_type(load_type)
		case load_type
		when "new"
			"new_items"
		when "popular"
			"popular_items"
		else
			"browse"
		end
	end

	# Flatten nested category structure (handles children arrays)
	def self.flatten_categories(menu)
		menu.flat_map do |cat|
			children = cat["children"] || []
			[cat] + flatten_categories(children)
		end
	end

	STYLING_STUDIO_URL = "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php"
	def self.load_styles_tab(species_id:, neologin:, tab:)
		Sync do
			DTIRequests.post(
				STYLING_STUDIO_URL,
				[
					["Content-Type", "application/x-www-form-urlencoded"],
					["Cookie", "neologin=#{neologin}"],
					["X-Requested-With", "XMLHttpRequest"],
				],
				{tab:, mode: "getAvailable", species: species_id}.to_query,
			) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{STYLING_STUDIO_URL})"
				end

				begin
					data = JSON.parse(response.read).deep_symbolize_keys

					# HACK: styles is a hash, unless it's empty, in which case it's an
					#       array? Weird. Normalize this by converting to hash.
					data.fetch(:styles).to_h.values.
						map { |s| s.slice(:oii, :name, :image, :limited) }
				rescue JSON::ParserError, KeyError
					raise UnexpectedResponseFormat
				end
			end
		end
	end

	# Given a string of v2 NC page data, parse the useful data out of it!
	def self.parse_nc_page(nc_page_str)
		begin
			nc_page = JSON.parse(nc_page_str)
		rescue JSON::ParserError
			Rails.logger.debug "Unexpected NC page response:\n#{nc_page_str}"
			raise UnexpectedResponseFormat,
				"failed to parse NC page response as JSON"
		end

		# v2 API returns items in a "data" array
		unless nc_page.has_key? "data"
			raise UnexpectedResponseFormat, "missing field data in v2 NC page"
		end

		item_data = nc_page["data"] || []

		items = item_data.map do |item_info|
			{
				id: item_info["id"],
				name: item_info["name"],
				description: item_info["description"],
				price: item_info["price"],
				discount: parse_item_discount(item_info),
				is_available: item_info["isAvailable"] == 1,
			}
		end

		{
			items:,
			total_pages: nc_page["totalPages"].to_i,
			page: nc_page["page"].to_i,
			limit: nc_page["limit"].to_i,
		}
	end

	# Given item info, return a hash of discount-specific info, if any.
	NST = Time.find_zone("Pacific Time (US & Canada)")
	def self.parse_item_discount(item_info)
		discount_price = item_info["discountPrice"]
		return nil unless discount_price.present? && discount_price > 0

		{
			price: discount_price,
			begins_at: NST.at(item_info["discountBegin"]),
			ends_at: NST.at(item_info["discountEnd"]),
		}
	end

	class ResponseNotOK < StandardError
		attr_reader :status
		def initialize(status)
			super
			@status = status
		end
	end
	class UnexpectedResponseFormat < StandardError;end
end
