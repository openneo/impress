require_relative '../rails_helper'

RSpec.describe NeologinCookie do
	describe ".current" do
		it "returns the most recently created cookie" do
			NeologinCookie.create!(cookie: "old", created_at: 2.days.ago)
			newer = NeologinCookie.create!(cookie: "new", created_at: 1.minute.ago)
			expect(NeologinCookie.current).to eq newer
		end

		it "returns nil when no cookies have been saved" do
			expect(NeologinCookie.current).to be_nil
		end
	end

	describe "#record_success!" do
		let(:cookie) do
			NeologinCookie.create!(
				cookie: "abc",
				last_failed_at: 1.hour.ago,
				last_failure_message: "boom",
				notified_failure_at: 1.hour.ago,
			)
		end

		it "stamps last_used_successfully_at and clears failure state" do
			cookie.record_success!
			cookie.reload
			expect(cookie.last_used_successfully_at).to be_within(2.seconds).of(Time.current)
			expect(cookie.last_failed_at).to be_nil
			expect(cookie.last_failure_message).to be_nil
			expect(cookie.notified_failure_at).to be_nil
		end
	end

	describe "#record_failure!" do
		let(:cookie) { NeologinCookie.create!(cookie: "abc") }

		it "stamps last_failed_at and last_failure_message" do
			expect(DiscordNotifier).to receive(:notify_neologin_failure)
			cookie.record_failure!(message: "401 Unauthorized")
			cookie.reload
			expect(cookie.last_failed_at).to be_within(2.seconds).of(Time.current)
			expect(cookie.last_failure_message).to eq "401 Unauthorized"
			expect(cookie.notified_failure_at).to be_within(2.seconds).of(Time.current)
		end

		it "fires Discord notification on first failure" do
			expect(DiscordNotifier).to receive(:notify_neologin_failure).
				with(cookie, message: "boom").once
			cookie.record_failure!(message: "boom")
		end

		it "doesn't re-notify on subsequent failures" do
			expect(DiscordNotifier).to receive(:notify_neologin_failure).once
			cookie.record_failure!(message: "first")
			cookie.record_failure!(message: "second")
			cookie.record_failure!(message: "third")
		end

		it "re-notifies after a success has cleared the prior failure" do
			expect(DiscordNotifier).to receive(:notify_neologin_failure).twice
			cookie.record_failure!(message: "first")
			cookie.record_success!
			cookie.record_failure!(message: "second")
		end

		it "truncates very long failure messages" do
			allow(DiscordNotifier).to receive(:notify_neologin_failure)
			cookie.record_failure!(message: "x" * 5000)
			cookie.reload
			expect(cookie.last_failure_message.length).to be <= 1000
		end
	end

	describe "#failing?" do
		it "is false with no recorded failure" do
			cookie = NeologinCookie.create!(cookie: "abc")
			expect(cookie.failing?).to be false
		end

		it "is true when a failure happened with no prior success" do
			cookie = NeologinCookie.create!(cookie: "abc", last_failed_at: 1.minute.ago)
			expect(cookie.failing?).to be true
		end

		it "is true when the latest failure is after the latest success" do
			cookie = NeologinCookie.create!(
				cookie: "abc",
				last_used_successfully_at: 1.hour.ago,
				last_failed_at: 1.minute.ago,
			)
			expect(cookie.failing?).to be true
		end

		it "is false when a success happened after the failure" do
			cookie = NeologinCookie.create!(
				cookie: "abc",
				last_used_successfully_at: 1.minute.ago,
				last_failed_at: 1.hour.ago,
			)
			expect(cookie.failing?).to be false
		end
	end
end
