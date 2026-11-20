# itemdb (https://itemdb.com.br/) is a community database of Neopets items.
# They use our data for their item previews, and they know about some items
# that we can't see ourselves: most notably, the names and thumbnails of NC
# Pet Style tokens that aren't currently in the Styling Studio.
#
# Their API requires a key, which you can create from an itemdb account. In
# return, they ask that we're clear about where we use their data, and link
# back to them. (See the credit on style tokens' item pages.)
#
# Authentication takes two steps: we trade our long-lived API key for a
# short-lived token, then send that token with each API request.
#
# We use their v2 endpoints with the "minimal" intent, at their suggestion:
# the responses are small, and well-cached on their end.
module Itemdb
	class Error < StandardError; end
	class NotConfigured < Error; end
	class NetworkError < Error; end

	API_KEY_ENV_VAR = "ITEMDB_API_KEY"
	TOKEN_URL = "https://itemdb.com.br/api/auth/token"

	# itemdb's tokens last an hour. We replace ours a bit early, to be safe.
	TOKEN_TTL = 50.minutes

	# itemdb's official "NC Pet Styles" list. It's maintained by hand, so it can
	# briefly lag behind new releases, or include an item that isn't actually a
	# style token. Callers should match on item ID, and not assume every entry
	# is a token!
	STYLE_TOKENS_LIST_URL =
		"https://itemdb.com.br/api/v2/lists/official/1037/itemdata"
	STYLE_TOKENS_LIST_PAGE_URL =
		"https://itemdb.com.br/lists/official/nc-pet-styles"

	# We stop paging after this many pages, in case something's gone wrong.
	# (Each page holds thousands of items, and the list is about one page long.)
	MAX_LIST_PAGES = 20

	ITEMS_URL = "https://itemdb.com.br/api/v2/items/many"

	# itemdb serves lookups of this size or smaller from its cache.
	MAX_ITEMS_PER_REQUEST = 100

	Item = Struct.new(:id, :name, :thumbnail_url, :description, :slug,
		keyword_init: true)

	class << self
		def configured?
			ENV[API_KEY_ENV_VAR].present?
		end

		# Forget our current API token, so the next request gets a new one.
		# Mainly for specs.
		def reset_token!
			@token = nil
		end

		# Load every item on itemdb's NC Pet Styles list. Returns a hash from
		# Neopets item ID to `Itemdb::Item`.
		def load_style_tokens
			items = {}

			(1..MAX_LIST_PAGES).each do |page|
				has_next_page = request(:get, "#{STYLE_TOKENS_LIST_URL}?" +
					{intent: "minimal", page:}.to_query) do |data, response|
					items.merge! parse_items(data)
					Array(response.headers["x-itemdb-has-next-page"]).first == "true"
				end
				return items unless has_next_page
			end

			raise NetworkError, "itemdb style list didn't end after " \
				"#{MAX_LIST_PAGES} pages"
		end

		# Look up items by their Neopets item IDs. Returns a hash from item ID to
		# `Itemdb::Item`. Items that itemdb doesn't know about are omitted.
		#
		# For style tokens, prefer `load_style_tokens`, which is one cached
		# request. This is for the stragglers that aren't on the list yet.
		def load_items(item_ids)
			item_ids.each_slice(MAX_ITEMS_PER_REQUEST).map { |ids|
				body = {type: "item_id", data: ids, intent: "minimal"}.to_json
				request(:post, ITEMS_URL, body) { |data| parse_items(data.values) }
			}.reduce({}, &:merge)
		end

		private

		def request(method, url, body = nil, &block)
			headers = [["X-Itemdb-Token", token]]
			headers << ["Content-Type", "application/json"] if body
			send_request(method, url, headers, body, &block)
		end

		# Trade our API key for a short-lived API token, and hold onto it until
		# it's close to expiring.
		def token
			raise NotConfigured, "#{API_KEY_ENV_VAR} is not set" unless configured?

			value, loaded_at = @token
			return value if value && Time.current - loaded_at < TOKEN_TTL

			value = send_request(
				:post, TOKEN_URL, [["X-Itemdb-Key", ENV[API_KEY_ENV_VAR]]]
			) do |data|
				data.is_a?(Hash) && data["token"].presence or
					raise NetworkError, "itemdb didn't return an API token"
			end
			@token = [value, Time.current].freeze
			value
		end

		def send_request(method, url, headers, body = nil)
			Sync do
				args = [url, headers]
				args << body if body
				DTIRequests.public_send(method, *args) do |response|
					if response.status != 200
						raise NetworkError,
							"itemdb returned status code #{response.status} " \
							"(expected 200) for #{url.split('?').first}"
					end

					begin
						data = JSON.parse(response.read)
					rescue JSON::ParserError => error
						raise NetworkError,
							"itemdb returned unsupported data format: #{error.message}"
					end

					yield data, response
				end
			rescue Async::TimeoutError => error
				raise NetworkError, "itemdb timed out: #{error.message}"
			rescue SocketError => error
				raise NetworkError, "Could not connect to itemdb: #{error.message}"
			end
		end

		def parse_items(items_data)
			unless items_data.is_a?(Array)
				raise NetworkError, "itemdb returned unexpected data: expected a " \
					"list of items, got #{items_data.class}"
			end

			# Skip items with no Neopets item ID: itemdb has some, but they can't
			# be style tokens we know about. (And skip items with no name, which
			# we'd have no use for, just in case.)
			usable_items_data = items_data.filter { |item_data|
				item_data["item_id"].present? && item_data["name"].present?
			}
			usable_items_data.to_h do |item_data|
				item = Item.new(
					id: item_data.fetch("item_id"),
					name: item_data.fetch("name"),
					thumbnail_url: item_data.fetch("image").fetch("url"),
					description: item_data["description"].presence,
					slug: item_data["slug"].presence,
				)
				[item.id, item]
			end
		rescue KeyError, NoMethodError => error
			raise NetworkError, "itemdb item was missing a field: #{error.message}"
		end
	end
end
