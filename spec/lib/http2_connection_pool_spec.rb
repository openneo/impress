require "async"
require "async/http"
require "protocol/http/body/writable"

# DTIRequests shares one long-lived async-http client per host (via
# `Async::HTTP::Internet.instance`), so concurrent requests multiplex streams
# over the same HTTP/2 connection to images.neopets.com. This guards against a
# connection-pool bug in async-pool < 0.12 that broke that sharing.
#
# The bug: when a request goes to acquire a connection and finds the pooled
# one no longer viable (e.g. the server has already hung up its end of the
# socket), async-pool 0.11 retired it on the spot, even with another fiber
# still using it. Once that other fiber's stream released the connection, the
# pool no longer knew about it, and raised:
#
#   RuntimeError: Trying to reuse unacquired resource:
#     #<Async::HTTP::Protocol::HTTP2::Client N active streams>!
#
# In production we saw "0 active streams": the other fiber's stream had
# already finished, and it released the connection while the retiring fiber
# was still partway through closing it. This spec hits the "1 active streams"
# variant of the same bug, where closing the connection cuts off the in-flight
# stream, which releases it right then. async-pool 0.12 waits for a
# non-viable connection's users to finish before retiring it, which fixes
# both.
RSpec.describe "HTTP/2 connection pooling" do
	# When webmock/rspec is loaded, WebMock swaps out Async::HTTP::Client for its
	# own wrapper, which would bypass the real pool we want to exercise here. So
	# use the original class, rather than toggling WebMock's global state.
	let(:client_class) do
		if defined?(WebMock::HttpLibAdapters::AsyncHttpClientAdapter::OriginalAsyncHttpClient)
			WebMock::HttpLibAdapters::AsyncHttpClientAdapter::OriginalAsyncHttpClient
		else
			Async::HTTP::Client
		end
	end

	let(:protocol) { Async::HTTP::Protocol::HTTP2 }

	# Responds to /slow with headers right away, then trickles out the body, so
	# the client is mid-response for a while.
	let(:app) do
		->(request) do
			if request.path == "/slow"
				body = Protocol::HTTP::Body::Writable.new
				Async do
					body.write("slow ")
					sleep 0.1
					body.write("done")
				ensure
					body.close_write
				end
				Protocol::HTTP::Response[200, {}, body]
			else
				Protocol::HTTP::Response[200, {}, ["fast done"]]
			end
		end
	end

	it "doesn't retire a connection out from under an in-flight response" do
		Sync do |task|
			bound = server_task = client = nil

			# If this regresses into a hang, fail fast rather than stalling the run.
			task.with_timeout(5) do
				bound = Async::HTTP::Endpoint.parse("http://127.0.0.1:0").bound
				port = bound.sockets.first.local_address.ip_port
				server = Async::HTTP::Server.new(app, bound, protocol:, scheme: "http")
				server_task = task.async { server.run }

				client = client_class.new(
					Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}", protocol:))

				# Start a slow request, and wait until it's reading its body.
				slow_response = client.get("/slow")
				slow_body = task.async { slow_response.read }

				# Make its connection look dead, as if the server had hung up its end
				# of the socket. (Getting a real server to do that at exactly the
				# wrong moment is too racy for a test.)
				expect(client.pool.resources.size).to eq(1)
				connection = client.pool.resources.keys.first
				def connection.viable? = false

				# Another request now needs a connection. It should get a fresh one,
				# and leave the slow one alone to finish.
				expect(client.get("/fast").read).to eq("fast done")
				expect(slow_body.wait).to eq("slow done")
			end
		ensure
			# Closing waits for in-use connections, so bound that wait too.
			begin
				task.with_timeout(1) { client&.close }
			rescue Async::TimeoutError
			end
			server_task&.stop
			bound&.close
		end
	end
end
