module LebronNCValues
	# NOTE: While we still have `updated_at` infra lying around from the Owls
	#       days, the current JSON file doesn't tell us that info, so it's always
	#       `nil` for now.
	Value = Struct.new(:value_text, :updated_at)

	class Error < StandardError;end
	class NetworkError < Error;end
	class NotFound < Error;end

	class << self
		def find_by_name(name)
			value_text = all_values[name.downcase]
			raise NotFound if value_text.nil? || value_text.strip == '-'

			Value.new(value_text, nil)
		end

		private

		def all_values
			Rails.cache.fetch('LebronNCValues.load_all_values', expires_in: 1.day) do
				Sync { load_all_values }
			end
		end

		ALL_VALUES_URL = "https://lebron-values.netlify.app/item_values.json"
		def load_all_values
			begin
				DTIRequests.get(ALL_VALUES_URL) do |response|
					if response.status != 200
						raise NetworkError,
							"Lebron returned status code #{response.status} (expected 200)"
					end

					begin
						JSON.parse(response.read)
					rescue JSON::ParserError => error
						raise NetworkError,
							"Lebron returned unsupported data format: #{error.message}"
					end
				end
			rescue Async::TimeoutError => error
				raise NetworkError, "Lebron timed out: #{error.message}"
			rescue SocketError => error
				raise NetworkError, "Could not connected to Lebron: #{error.message}"
			end
		end
	end
end
