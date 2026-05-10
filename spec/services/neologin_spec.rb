require_relative '../rails_helper'

RSpec.describe Neologin do
	around do |example|
		original = ENV["NEOLOGIN_COOKIE"]
		ENV.delete("NEOLOGIN_COOKIE")
		example.run
		ENV["NEOLOGIN_COOKIE"] = original
	end

	describe ".cookie" do
		it "returns the latest DB cookie when one exists" do
			NeologinCookie.create!(cookie: "from-db", created_at: 1.minute.ago)
			expect(Neologin.cookie).to eq "from-db"
		end

		it "prefers the DB cookie over the env var" do
			NeologinCookie.create!(cookie: "from-db", created_at: 1.minute.ago)
			ENV["NEOLOGIN_COOKIE"] = "from-env"
			expect(Neologin.cookie).to eq "from-db"
		end

		it "falls back to NEOLOGIN_COOKIE when no DB cookie exists" do
			ENV["NEOLOGIN_COOKIE"] = "from-env"
			expect(Neologin.cookie).to eq "from-env"
		end

		it "raises when no cookie is configured anywhere" do
			expect { Neologin.cookie }.to raise_error(Neologin::MissingCookie)
		end
	end

	describe ".cookie?" do
		it "is true with a DB cookie" do
			NeologinCookie.create!(cookie: "x")
			expect(Neologin.cookie?).to be true
		end

		it "is true with only an env var cookie" do
			ENV["NEOLOGIN_COOKIE"] = "x"
			expect(Neologin.cookie?).to be true
		end

		it "is false with neither" do
			expect(Neologin.cookie?).to be false
		end
	end

	describe ".with_tracking" do
		context "with a DB cookie" do
			let!(:cookie) { NeologinCookie.create!(cookie: "x") }

			it "records success and returns the block's value when it returns" do
				result = Neologin.with_tracking { "yay" }
				expect(result).to eq "yay"
				expect(cookie.reload.last_used_successfully_at).to be_present
			end

			it "records failure and re-raises when the block raises" do
				allow(DiscordNotifier).to receive(:notify_neologin_failure)
				expect {
					Neologin.with_tracking { raise StandardError, "kaboom" }
				}.to raise_error(StandardError, "kaboom")
				cookie.reload
				expect(cookie.last_failed_at).to be_present
				expect(cookie.last_failure_message).to include "kaboom"
			end
		end

		context "with no DB cookie" do
			it "still runs the block (env-var-only mode)" do
				expect(Neologin.with_tracking { 42 }).to eq 42
			end

			it "still propagates errors" do
				expect { Neologin.with_tracking { raise "x" } }.to raise_error("x")
			end
		end
	end
end
