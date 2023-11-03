module OwlsValueGuide
	include HTTParty

	ITEMDATA_URL_TEMPLATE = Addressable::Template.new(
    "https://neo-owls.net/itemdata/{item_name}"
  )

	def self.find_by_name(item_name)
		# Load the itemdata, pulling from the Rails cache if possible.
		cache_key = "OwlsValueGuide/itemdata/#{item_name}"
		data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
			load_itemdata(item_name)
		end

		if data == :not_found
			raise NotFound
		end

		# Owls has records of some items that it explicitly marks as having no
		# listed value. We don't care about that distinction, just return nil!
		return nil if data['owls_value'].blank?

		Value.new(data['owls_value'], parse_last_updated(data['last_updated']))
	end

	Value = Struct.new(:value_text, :updated_at)

	class Error < StandardError;end
	class NetworkError < Error;end
	class NotFound < Error;end

	private

	def self.load_itemdata(item_name)
		Rails.logger.info "[OwlsValueGuide] Loading value for #{item_name.inspect}"

		url = ITEMDATA_URL_TEMPLATE.expand(item_name: item_name)
		begin
			res = get(url)
		rescue StandardError => error
			raise NetworkError, "Couldn't connect to Owls: #{error.message}"
		end

		if res.code == 404
			# Instead of raising immediately, return `:not_found` to save this
			# result in the cache, then raise *after* we exit the cache block. That
			# way, we won't make repeat requests for items we have that Owls
			# doesn't.
			return :not_found
		end

		if res.code != 200
			raise NetworkError, "Owls returned status code #{res.code} (expected 200)"
		end

		begin
			res.parsed_response
		rescue HTTParty::Error => error
			raise NetworkError, "Owls returned unsupported data format: #{error.message}"
		end
	end

	def self.parse_last_updated(date_str)
		return nil if date_str.blank?

		begin
			Date.strptime(date_str, '%Y-%m-%d')
		rescue Date::Error
			Rails.logger.error(
				"[OwlsValueGuide] unexpected last_updated format: #{date_str.inspect}"
			)
			return nil
		end
	end
end
