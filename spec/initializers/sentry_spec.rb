require 'rails_helper'
require 'async'
require 'sentry/test_helper'

RSpec.describe "Sentry configuration" do
  include Sentry::TestHelper

  before { setup_sentry_test }
  after { teardown_sentry_test }

  it "isolates each fiber's scope, so concurrent requests don't mix context" do
    other_request_started = Async::Condition.new
    crash_reported = Async::Condition.new

    inner_app = ->(env) do
      case env["PATH_INFO"]
      when "/crashes"
        # Wait until another request has set up its scope on this same thread,
        # like Falcon interleaving two requests.
        other_request_started.wait
        raise "Oh no"
      when "/other"
        other_request_started.signal
        crash_reported.wait
        [200, {}, ["OK"]]
      end
    end
    app = Sentry::Rack::CaptureExceptions.new(inner_app)

    Sync do |task|
      crashing = task.async do
        app.call(Rack::MockRequest.env_for("https://example.com/crashes"))
      rescue RuntimeError
        crash_reported.signal
      end
      other = task.async do
        app.call(Rack::MockRequest.env_for("https://example.com/other"))
      end
      [crashing, other].each(&:wait)
    end

    expect(sentry_events.size).to eq 1
    event = sentry_events.first
    expect(event.transaction).to eq "/crashes"
    expect(event.request.url).to eq "https://example.com/crashes"
  end
end
