require "async"
require "async/barrier"
require "async/http/internet/instance"

module DTIRequests
	class << self
		def get(url, headers = [], &block)
			Async::HTTP::Internet.get(url, ensure_headers(headers), &block)
		end

		def post(url, headers = [], body = nil, &block)
			Async::HTTP::Internet.post(url, ensure_headers(headers), body, &block)
		end

		def load_many(max_at_once: 10)
			barrier = Async::Barrier.new
			semaphore = Async::Semaphore.new(max_at_once, parent: barrier)

			Sync do
				block_return_value = yield semaphore
				barrier.wait # Load all the subtasks.
				block_return_value
			ensure
				barrier.stop # If any subtasks failed, cancel the rest.
			end
		end

		private

		def ensure_headers(headers)
			# To access Neopets.com, requests must have a User-Agent header that
			# contains a slash.
			headers = ensure_header(headers, "User-Agent", Rails.configuration.user_agent_for_neopets)

			# To access Neopets.com, requests must have the following headers
			# present, even with the most basic value possible.
			headers = ensure_header(headers, "Accept", "*/*")
			headers = ensure_header(headers, "Accept-Language", "*")
			headers = ensure_header(headers, "Cookie", " ")

			# NOTE: An Accept-Encoding header is also required, but the underlying
			#       library already manages this. Don't mess with it!

			headers
		end

		def ensure_header(headers, name, value)
			if headers.none? { |(k, v)| k.downcase == name.downcase }
				headers += [[name, value]]
			end

			headers
		end
	end
end
