require "addressable/template"
require "async/http/internet/instance"

module NCMall
	# Share a pool of persistent connections, rather than reconnecting on
	# each request. (This library does that automatically!)
	INTERNET = Async::HTTP::Internet.instance

	# Load the NC home page, and return its useful data.
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

	private

	def self.load_page_by_url(url)
		Sync do
			response = INTERNET.get(url, [
				["User-Agent", Rails.configuration.user_agent_for_neopets],
			])

			if response.status != 200
				raise ResponseNotOK.new(response.status),
					"expected status 200 but got #{response.status} (#{url})"
			end

			parse_nc_page response.read
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

		items = nc_page["object_data"].values.map do |item_info|
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
			start: item_info["discountBegin"],
			end: item_info["discountEnd"],
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
