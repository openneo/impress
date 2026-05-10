require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe DiscordNotifier do
	around do |example|
		original = ENV["NEOLOGIN_DISCORD_WEBHOOK_URL"]
		example.run
		ENV["NEOLOGIN_DISCORD_WEBHOOK_URL"] = original
	end

	describe ".notify_neologin_failure" do
		let(:cookie) { NeologinCookie.create!(cookie: "abc") }

		it "POSTs a message to the configured webhook" do
			ENV["NEOLOGIN_DISCORD_WEBHOOK_URL"] = "https://discord.example/webhook/123"
			stub = stub_request(:post, "https://discord.example/webhook/123").
				with { |req|
					body = JSON.parse(req.body)
					body["content"].include?("Neologin cookie failed") &&
						body["content"].include?("401 Unauthorized")
				}.
				to_return(status: 204)

			DiscordNotifier.notify_neologin_failure(cookie, message: "401 Unauthorized")

			expect(stub).to have_been_requested
		end

		it "logs and skips when the webhook URL is unset" do
			ENV.delete("NEOLOGIN_DISCORD_WEBHOOK_URL")
			expect(Rails.logger).to receive(:warn).with(/NEOLOGIN_DISCORD_WEBHOOK_URL/)
			expect {
				DiscordNotifier.notify_neologin_failure(cookie, message: "boom")
			}.not_to raise_error
		end

		it "doesn't raise when the webhook errors" do
			ENV["NEOLOGIN_DISCORD_WEBHOOK_URL"] = "https://discord.example/webhook/123"
			stub_request(:post, "https://discord.example/webhook/123").
				to_return(status: 500, body: "uh oh")
			expect {
				DiscordNotifier.notify_neologin_failure(cookie, message: "boom")
			}.not_to raise_error
		end
	end
end
