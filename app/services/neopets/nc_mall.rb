require "addressable/template"
require "async/http/internet/instance"

module Neopets::NCMall
	# Share a pool of persistent connections, rather than reconnecting on
	# each request. (This library does that automatically!)
	INTERNET = Async::HTTP::Internet.instance

	# Load the NC Mall home page content area, and return its useful data.
	HOME_PAGE_URL = "https://ncmall.neopets.com/mall/ajax/home_page.phtml"
	def self.load_home_page
		load_page_by_url HOME_PAGE_URL
	end

	# Load the NC Mall page for a specific type and category ID.
	CATEGORY_PAGE_URL_TEMPLATE = Addressable::Template.new(
		"https://ncmall.neopets.com/mall/ajax/load_page.phtml?lang=en{&type,cat}"
	)
	def self.load_page(type, cat)
		load_page_by_url CATEGORY_PAGE_URL_TEMPLATE.expand(type:, cat:)
	end

	# Load the NC Mall root document HTML, and extract the list of links to
	# other pages ("New", "Popular", etc.)
	ROOT_DOCUMENT_URL = "https://ncmall.neopets.com/mall/shop.phtml"
	PAGE_LINK_PATTERN = /load_items_pane\(['"](.+?)['"], ([0-9]+)\).+?>(.+?)</
	def self.load_page_links
		html = Sync do
			INTERNET.get(ROOT_DOCUMENT_URL, [
				["User-Agent", Rails.configuration.user_agent_for_neopets],
			]) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{url})"
				end

				response.read
			end
		end

		# Extract `load_items_pane` calls from the root document's HTML. (We use
		# a very simplified regex, rather than actually parsing the full HTML!)
		html.scan(PAGE_LINK_PATTERN).
			map { |type, cat, label| {type:, cat:, label:} }.
			uniq
	end

	STYLING_STUDIO_URL = "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php"
	def self.load_styles(species_id:, neologin:)
		Sync do
			INTERNET.post(
				STYLING_STUDIO_URL,
				headers: [
					["User-Agent", Rails.configuration.user_agent_for_neopets],
					["Content-Type", "application/x-www-form-urlencoded"],
					["Cookie", "neologin=#{neologin}"],
					["X-Requested-With", "XMLHttpRequest"],
				],
				body: {tab: 1, mode: "getStyles", species: species_id}.to_query,
			) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{STYLING_STUDIO_URL})"
				end

				begin
					data = JSON.parse(response.read).deep_symbolize_keys

					# HACK: styles is a hash, unless it's empty, in which case it's an
					#       array? Weird. Normalize this by converting to hash.
					data.fetch(:styles).to_h.values
				rescue JSON::ParserError, KeyError
					raise UnexpectedResponseFormat
				end
			end
		end
	end

	private

	def self.load_page_by_url(url)
		Sync do
			INTERNET.get(url, [
				["User-Agent", Rails.configuration.user_agent_for_neopets],
			]) do |response|
				if response.status != 200
					raise ResponseNotOK.new(response.status),
						"expected status 200 but got #{response.status} (#{url})"
				end

				parse_nc_page response.read
			end
		end
	end

	# Given a string of NC page data, parse the useful data out of it!
	def self.parse_nc_page(nc_page_str)
		begin
			nc_page = JSON.parse(nc_page_str)
		rescue JSON::ParserError
			Rails.logger.debug "Unexpected NC page response:\n#{nc_page_str}"
			raise UnexpectedResponseFormat,
				"failed to parse NC page response as JSON"
		end

		unless nc_page.has_key? "object_data"
			raise UnexpectedResponseFormat, "missing field object_data in NC page"
		end

		object_data = nc_page["object_data"]

		# NOTE: When there's no object data, it will be an empty array instead of
		# an empty hash. Weird API thing to work around!
		object_data = {} if object_data == []

		# Only the items in the `render` list are actually listed as directly for
		# sale in the shop. `object_data` might contain other items that provide
		# supporting information about them, but aren't actually for sale.
		visible_object_data = (nc_page["render"] || []).
			map { |id| object_data[id.to_s] }.
			filter(&:present?)

		items = visible_object_data.map do |item_info|
			{
				id: item_info["id"],
				name: item_info["name"],
				description: item_info["description"],
				price: item_info["price"],
				discount: parse_item_discount(item_info),
				is_available: item_info["isAvailable"] == 1,
			}
		end

		{items:}
	end

	# Given item info, return a hash of discount-specific info, if any.
	def self.parse_item_discount(item_info)
		discount_price = item_info["discountPrice"]
		return nil unless discount_price.present? && discount_price > 0

		{
			price: discount_price,
			begins_at: item_info["discountBegin"],
			ends_at: item_info["discountEnd"],
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
