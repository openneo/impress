#!/usr/bin/env -S falcon host
# frozen_string_literal: true

load :rack

hostname = File.basename(__dir__)
rack hostname do
	endpoint Async::HTTP::Endpoint.parse('http://localhost:3000').
		with(protocol: Async::HTTP::Protocol::HTTP1)

	# How many worker processes to fork. In production, the service file sets
	# this right next to its memory cap, because the two need to be chosen
	# together. If unset, Falcon defaults to one worker per CPU core.
	count ENV["FALCON_COUNT"]&.to_i
end
