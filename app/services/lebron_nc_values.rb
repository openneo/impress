module LebronNCValues
	# NOTE: While we still have `updated_at` infra lying around from the Owls
	#       days, the current JSON file doesn't tell us that info, so it's always
	#       `nil` for now.
	Value = Struct.new(:value_text, :updated_at)

	class Error < StandardError;end
	class NetworkError < Error;end
	class NotFound < Error;end

	# How long each process keeps its parsed copy of the values. The
	# `Rails.cache` layer underneath lasts longer, and keeps a fresh process
	# from having to hit the network.
	IN_MEMORY_TTL = 1.hour

	class << self
		def find_by_name(name)
			value_text = all_values[name.downcase]
			raise NotFound if value_text.nil? || value_text.strip == '-'

			Value.new(value_text, nil)
		end

		# Drops this process's in-memory copy, so the next lookup goes back to
		# `Rails.cache`. Mainly for specs.
		def reset_in_memory_values!
			@memoized = nil
		end

		private

		# Reading from `Rails.cache` deserializes the whole hash (the default
		# FileStore Marshal-loads it from disk), which is wasteful to do once per
		# item. So, we hold on to the parsed hash in memory for a while.
		#
		# No mutex: the values and their load time live together in one frozen
		# pair that's swapped in with a single assignment, so readers never see
		# a half-updated state. The worst case is a redundant load.
		#
		# If loading raises (e.g. NetworkError), nothing is memoized, so the next
		# call retries.
		def all_values
			now = Time.current
			memoized = @memoized
			if memoized && now - memoized[1] < IN_MEMORY_TTL
				return memoized[0]
			end

			values = Rails.cache.fetch('LebronNCValues.load_all_values', expires_in: 1.day) do
				Sync { load_all_values }
			end
			@memoized = [values.freeze, now].freeze
			values
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
