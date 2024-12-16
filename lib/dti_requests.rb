require "async"
require "async/barrier"
require "async/http/internet/instance"

module DTIRequests
	class << self
		def get(url, headers = [], &block)
			Async::HTTP::Internet.get(url, add_headers(headers), &block)
		end

		def post(url, headers = [], body = nil, &block)
			Async::HTTP::Internet.post(url, add_headers(headers), body, &block)
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

		def add_headers(headers)
			if headers.none? { |(k, v)| k.downcase == "user-agent" }
				headers += [["User-Agent", Rails.configuration.user_agent_for_neopets]]
			end
			headers
		end
	end
end
