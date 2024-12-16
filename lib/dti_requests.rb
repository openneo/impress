require "async"
require "async/barrier"

module DTIRequests
	class << self
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
	end
end
